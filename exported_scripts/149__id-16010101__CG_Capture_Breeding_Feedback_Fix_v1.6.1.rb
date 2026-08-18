# RMVX_SCRIPT_INDEX: 149
# RMVX_SCRIPT_ID: 16010101
# RMVX_SCRIPT_NAME: CG Capture Breeding Feedback Fix v1.6.1
# RMVX_SOURCE_SHA256: bec75247a9db8f35e47ecd45ea6a5c1454939f17e529b3bc5da74a8113eca98c

#==============================================================================
# 【繁體中文說明】ALBERT CG 捕捉／配種回饋與指令視窗修正
#------------------------------------------------------------------------------
# 【版本】v1.6.1
# 【用途】
#  1. 修正 F5 寵物管理右下角指令視窗捲動後出現兩列空白。
#  2. 捕捉成功後，立刻從本回合行動佇列與行動順序預覽中移除目標。
#  3. 捕捉成功時播放成功音效、顯示正式戰鬥訊息，並讓主角播放
#     Tankentai SBS 的 victory 動作。
#  4. 配種成功後以 RPG Maker VX 標準對話視窗顯示子代結果。
#
# 【F5 空白列原因】
#  VX 的 Window_Command 會在設定真正的 @item_max 之前建立 contents。
#  當指令超過視窗可見五列時，後面的文字其實被畫到太小的 Bitmap 外面。
#  本修正於指令建立後重新 create_contents／refresh，保留原有七項指令與索引。
#
# 【捕捉成功設定】
#  CAPTURE_SUCCESS_ME_NAME   ：Audio/ME 內的成功音效名稱，不含副檔名。
#  CAPTURE_SUCCESS_ME_VOLUME ：音量。
#  CAPTURE_SUCCESS_ME_PITCH  ：音高。
#  專案目前內建 Audio/ME/Win Battle.mp3，因此預設使用 "Win Battle"。
#
# 【配種規則】
#  本腳本不改變 v1.6 已定案規則：
#  - 只能由同一進化系譜的異性個體配種。
#  - 不同型態可以互相配種。
#  - 子代固定回到該系譜第一型態。
#
# 【腳本位置】
#  放在 CG Gender Nature Core v1.6 下方、Main 上方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_CaptureBreedingFeedbackFix"] = true

module ALBERT_CG
  CAPTURE_BREEDING_FEEDBACK_VERSION = "1.6.1" unless const_defined?(:CAPTURE_BREEDING_FEEDBACK_VERSION)
  CAPTURE_SUCCESS_ME_NAME = "Win Battle" unless const_defined?(:CAPTURE_SUCCESS_ME_NAME)
  CAPTURE_SUCCESS_ME_VOLUME = 70 unless const_defined?(:CAPTURE_SUCCESS_ME_VOLUME)
  CAPTURE_SUCCESS_ME_PITCH = 110 unless const_defined?(:CAPTURE_SUCCESS_ME_PITCH)

  def self.play_capture_success_sound
    RPG::ME.new(CAPTURE_SUCCESS_ME_NAME,
      CAPTURE_SUCCESS_ME_VOLUME, CAPTURE_SUCCESS_ME_PITCH).play
    return true
  rescue
    begin
      Sound.play_recovery
    rescue
      Sound.play_decision
    end
    return false
  end

  def self.apply_v161_title
    return if $data_system == nil
    $data_system.game_title = "CG Pet Battle Prototype v1.6.1"
  end
end

#==============================================================================
# ■ F5 寵物管理：重建完整指令 Bitmap
#==============================================================================
if defined?(Scene_CG_PetLab)
  class Scene_CG_PetLab < Scene_Base
    alias albert_cg_v161_feedback_rebuild_command_window rebuild_command_window
    def rebuild_command_window
      albert_cg_v161_feedback_rebuild_command_window
      if @command_window != nil && !@command_window.disposed?
        @command_window.create_contents
        @command_window.refresh
      end
    end
  end
end

#==============================================================================
# ■ 行動順序預覽：隱藏已死亡／逃離／捕捉的 Battler
#==============================================================================
if defined?(Window_CG_ActionOrder)
  class Window_CG_ActionOrder < Window_Base
    alias albert_cg_v161_feedback_valid_order_entry cg_valid_entry?
    def cg_valid_entry?(entry)
      battler = cg_entry_battler(entry)
      return false if battler == nil
      if battler.respond_to?(:exist?)
        return false unless battler.exist?
      end
      return albert_cg_v161_feedback_valid_order_entry(entry)
    end
  end
end

#==============================================================================
# ■ Scene_Battle：捕捉成功回饋與行動佇列清理
#==============================================================================
if defined?(Scene_Battle)
  class Scene_Battle < Scene_Base
    def cg_v161_remove_captured_battler_from_order(target)
      return if target == nil
      if @action_battlers != nil
        @action_battlers.delete_if do |entry|
          battler = if defined?(ALBERT_CG::ActionEntry) &&
                       entry.is_a?(ALBERT_CG::ActionEntry)
            entry.battler
          else
            entry
          end
          battler == nil || battler == target ||
            (battler.respond_to?(:exist?) && !battler.exist?)
        end
      end
      if $game_troop != nil && $game_troop.respond_to?(:forcing_battler)
        if $game_troop.forcing_battler == target
          $game_troop.forcing_battler = nil
        end
      end
      if @cg_action_order_window != nil
        action = @active_battler == nil ? nil : @active_battler.action
        @cg_action_order_window.set_order(@active_battler, action,
          @action_battlers == nil ? [] : @action_battlers)
      end
    end

    def cg_v161_capture_destination_text(pet)
      destination = @cg_v07_capture_destination
      if destination == nil && $game_party.respond_to?(:cg_pet_location)
        destination = $game_party.cg_pet_location(pet.id)
      end
      @cg_v07_capture_destination = nil
      return destination == :storage ? "寵物倉庫" : "攜帶名冊"
    end

    def cg_v161_play_capture_victory(user)
      return false if user == nil || @spriteset == nil
      return false unless @spriteset.respond_to?(:set_action)
      index = user.index
      return false if index == nil
      action = user.respond_to?(:win) ? user.win : "VICTORY"
      @spriteset.set_action(true, index, action)
      return true
    rescue
      return false
    end

    def cg_v161_restore_capture_user_pose(user)
      return if user == nil || @spriteset == nil
      return unless @spriteset.respond_to?(:set_action)
      return if $game_troop != nil && $game_troop.existing_members.empty?
      index = user.index
      return if index == nil
      action = user.respond_to?(:normal) ? user.normal : "WAIT"
      @spriteset.set_action(true, index, action)
    rescue
    end

    def cg_v161_show_capture_success(user, pet, rate)
      place = cg_v161_capture_destination_text(pet)
      identity = ""
      if pet.respond_to?(:cg_gender_symbol) && pet.respond_to?(:cg_nature_name)
        identity = " " + pet.cg_gender_symbol.to_s + "／" + pet.cg_nature_name.to_s
      end
      ALBERT_CG.play_capture_success_sound
      cg_v161_play_capture_victory(user)
      $game_message.clear
      $game_message.face_name = ""
      $game_message.face_index = 0
      $game_message.background = 0
      $game_message.position = 2
      $game_message.texts.push("捕捉成功！")
      $game_message.texts.push(user.name.to_s + "捕捉了" + pet.name.to_s + identity + "。")
      $game_message.texts.push("個體 #" + pet.id.to_s + " 已加入" + place + "。")
      $game_message.texts.push("本次捕捉成功率：" + rate.to_s + "%")
      wait_for_message
      cg_v161_restore_capture_user_pose(user)
    end

    # 完整覆寫最後一層捕捉執行，保留 v0.6.5 的權威物種判定。
    def cg_execute_capture_action
      user = @active_battler
      target = cg_capture_target_from_action
      card = cg_capture_card

      if user == nil || user.id.to_i != ALBERT_CG::PRIMARY_PET_HANDLER_ACTOR_ID
        cg_show_special_action_text("捕捉失敗：只有主角能使用封印卡。")
        return
      end
      if target == nil || !target.exist?
        cg_show_special_action_text("捕捉取消：原本的目標已不在戰場。")
        return
      end
      if ALBERT_CG.respond_to?(:cg_resolve_capture_species_id)
        species_id = ALBERT_CG.cg_resolve_capture_species_id(target)
        if species_id.to_i <= 0
          cg_show_special_action_text("捕捉失敗：找不到目標的物種設定。")
          return
        end
      end
      unless target.respond_to?(:cg_capturable?) && target.cg_capturable?
        cg_show_special_action_text("捕捉失敗：這個目標無法封印。")
        return
      end
      if card == nil || $game_party.item_number(card) <= 0
        cg_show_special_action_text("捕捉失敗：沒有封印卡。")
        return
      end

      rate = target.cg_capture_chance(user, card)
      $game_party.consume_item(card)
      display_animation([target], ALBERT_CG::CAPTURE_ANIMATION_ID)

      if rand(100) < rate
        pet = cg_create_captured_pet(target)
        if pet != nil
          target.escape
          cg_v161_remove_captured_battler_from_order(target)
          @status_window.refresh if @status_window != nil
          cg_v161_show_capture_success(user, pet, rate)
        else
          $game_party.gain_item(card, 1)
          cg_show_special_action_text("捕捉資料建立失敗，封印卡已退回。")
        end
      else
        if ALBERT_CG::CAPTURE_FAILURE_ANIMATION_ID.to_i > 0
          display_animation([target], ALBERT_CG::CAPTURE_FAILURE_ANIMATION_ID)
        end
        cg_show_special_action_text(user.name.to_s + "沒有成功封印" +
          target.name.to_s + "。　成功率 " + rate.to_s + "%")
      end
    end
  end
end

#==============================================================================
# ■ Scene_CG_PetBreeding：標準對話視窗顯示孵化結果
#==============================================================================
if defined?(Scene_CG_PetBreeding)
  class Scene_CG_PetBreeding < Scene_Base
    alias albert_cg_v161_feedback_breed_start start
    def start
      albert_cg_v161_feedback_breed_start
      @cg_v161_breed_message_window = Window_Message.new
      @cg_v161_breed_message_window.z = 500
    end

    alias albert_cg_v161_feedback_breed_terminate terminate
    def terminate
      if @cg_v161_breed_message_window != nil
        unless @cg_v161_breed_message_window.disposed?
          @cg_v161_breed_message_window.dispose
        end
        @cg_v161_breed_message_window = nil
      end
      albert_cg_v161_feedback_breed_terminate
    end

    alias albert_cg_v161_feedback_breed_update update
    def update
      if @cg_v161_breed_message_window != nil
        @cg_v161_breed_message_window.update
        if $game_message.busy || $game_message.visible
          super
          update_menu_background
          return
        end
      end
      albert_cg_v161_feedback_breed_update
    end

    def cg_v161_show_breed_result(child, place, skill_names)
      grade_text = if ALBERT_CG.respond_to?(:pet_grade_rank_text)
        ALBERT_CG.pet_grade_rank_text(child)
      else
        values = []
        5.times { |i| values.push(child.cg_grade_loss_at(i).to_s) }
        values.join("／")
      end
      identity = ""
      if child.respond_to?(:cg_gender_symbol) && child.respond_to?(:cg_nature_name)
        identity = " " + child.cg_gender_symbol.to_s + "／" + child.cg_nature_name.to_s
      end
      skills = skill_names.empty? ? "無" : skill_names.join("、")
      $game_message.clear
      $game_message.face_name = ""
      $game_message.face_index = 0
      $game_message.background = 0
      $game_message.position = 2
      $game_message.texts.push("孵化成功：" + child.name.to_s + identity)
      $game_message.texts.push("個體 #" + child.id.to_s + "　世代 G" + child.cg_generation.to_s + "　Lv." + child.level.to_s)
      $game_message.texts.push("掉檔：" + grade_text.to_s)
      $game_message.texts.push("加入" + place.to_s + "　繼承技能：" + skills)
    end

    # 沿用 v1.6 的性別與同系譜規則，只改成功後的顯示方式。
    def select_pet
      pet = @list_window.pet
      if pet == nil || !pet.cg_breed_available?
        Sound.play_buzzer
        @info_window.text = "此個體目前不能配種。\n需存活、異性別資格、Lv." + ALBERT_CG::PET_BREED_MIN_LEVEL.to_s + "以上且次數未滿。"
        return
      end
      if @parent_a == nil
        Sound.play_decision
        @parent_a = pet
        @info_window.text = "第一親本：" + pet.name + " " + pet.cg_gender_symbol + " #" + pet.id.to_s + "\n請選擇同系譜的異性第二親本。"
        @list_window.refresh
        update_detail
        return
      end
      if pet == @parent_a
        Sound.play_buzzer
        @info_window.text = "不能選擇同一個體作為雙親。"
        return
      end
      unless @parent_a.cg_opposite_gender_with?(pet)
        Sound.play_buzzer
        @info_window.text = "同性別或無性別個體無法配對。"
        return
      end
      base_a = @parent_a.respond_to?(:cg_evolution_base_form) ? @parent_a.cg_evolution_base_form : @parent_a.cg_species_id
      base_b = pet.respond_to?(:cg_evolution_base_form) ? pet.cg_evolution_base_form : pet.cg_species_id
      if base_a.to_i != base_b.to_i
        Sound.play_buzzer
        @info_window.text = "進化系譜不相同。\n只有同一系譜的不同型態可以配種。"
        return
      end
      unless @parent_a.cg_breed_compatible_with?(pet)
        Sound.play_buzzer
        @info_window.text = "此組合目前不符合配種條件。"
        return
      end
      unless $game_party.cg_breeding_capacity_available?
        Sound.play_buzzer
        @info_window.text = "攜帶名冊與寵物倉庫都已滿。"
        return
      end

      child = $game_party.cg_breed_pets(@parent_a.id, pet.id)
      if child == nil
        Sound.play_buzzer
        @info_window.text = "配種失敗，請檢查個體與容量。"
        return
      end
      child.cg_prepare_identity_data if child.respond_to?(:cg_prepare_identity_data)
      Sound.play_decision
      destination = $game_party.respond_to?(:cg_pet_location) ? $game_party.cg_pet_location(child.id) : nil
      place = destination == :storage ? "寵物倉庫" : "攜帶名冊"
      skill_names = []
      for skill_id in child.cg_inherited_skill_ids
        skill = $data_skills[skill_id]
        skill_names.push(skill.name) if skill != nil
      end
      @info_window.text = "最近孵化：" + child.name.to_s + " #" + child.id.to_s + "\n已加入" + place + "。"
      @parent_a = nil
      @list_window.refresh
      update_detail
      cg_v161_show_breed_result(child, place, skill_names)
    end
  end
end

#==============================================================================
# ■ Scene_Title：版本標題
#==============================================================================
class Scene_Title < Scene_Base
  alias albert_cg_v161_feedback_load_database load_database
  def load_database
    albert_cg_v161_feedback_load_database
    ALBERT_CG.apply_v161_title
  end

  alias albert_cg_v161_feedback_load_bt_database load_bt_database
  def load_bt_database
    albert_cg_v161_feedback_load_bt_database
    ALBERT_CG.apply_v161_title
  end
end
