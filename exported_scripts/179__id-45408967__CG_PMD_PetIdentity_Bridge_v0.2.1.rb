# RMVX_SCRIPT_INDEX: 179
# RMVX_SCRIPT_ID: 45408967
# RMVX_SCRIPT_NAME: CG_PMD_PetIdentity_Bridge v0.2.1
# RMVX_SOURCE_SHA256: 28dc493a05a35febaea841ee74a426609fbd9b93bf5e642155428928d26e8edd

#==============================================================================
# ■ CG_PMD_PetIdentity_Bridge.rb  v0.2.1
#------------------------------------------------------------------------------
#  魔力寶貝專案的寵物物種身分層。
#
#  原則：
#  1. 不使用 VX 不存在的 Actor Note／Class Note。
#  2. PMD 圖像綁定「物種模板 Actor ID」，不是 Clone 的動態 Actor ID。
#  3. 改名、入庫、出庫、隊伍替換不改物種。
#  4. 配種生成子代與進化時，透過下方公開 API 更新物種。
#  5. 這些 ivar 會隨 Game_Actor 一起 Marshal 存檔，不需要另改 Scene_File。
#  6. VX 原生 Game_Actor 只有 id，沒有 actor_id reader；v0.2.1 起會同時
#     支援 actor.id，避免直接使用正式 Actor 時 PMD 身分判定失敗。
#==============================================================================
$imported = {} if $imported == nil
$imported["CG_PMD_PetIdentity_Bridge"] = CG_PMD::VERSION

module CG_PMD
  #--------------------------------------------------------------------------
  # ● 安全取得整數
  #--------------------------------------------------------------------------
  def self.integer_or_nil(value)
    return value if value.is_a?(Integer)
    return nil if value == nil
    text = value.to_s
    return nil unless text =~ /^\d+$/
    return text.to_i
  end

  #--------------------------------------------------------------------------
  # ● 判定是否為已登錄物種
  #--------------------------------------------------------------------------
  def self.registered_species?(species_id)
    id = integer_or_nil(species_id)
    return false if id == nil
    return SPECIES_SPRITES.has_key?(id)
  end

  #--------------------------------------------------------------------------
  # ● 由 Game_Actor 解出物種模板 Actor ID
  #--------------------------------------------------------------------------
  def self.actor_species_id(actor)
    return nil if actor == nil

    explicit = actor.instance_variable_get(:@cg_pmd_species_id)
    return explicit.to_i if registered_species?(explicit)

    SPECIES_READER_METHODS.each do |method_name|
      next unless actor.respond_to?(method_name)
      begin
        value = actor.send(method_name)
      rescue
        value = nil
      end
      return value.to_i if registered_species?(value)
    end

    # 非 Clone／直接正式 Actor 的最後 fallback。
    # RPG Maker VX 的 Game_Actor 原生公開方法是 id，不是 actor_id。
    if actor.respond_to?(:actor_id) && registered_species?(actor.actor_id)
      return actor.actor_id.to_i
    end
    if actor.respond_to?(:id) && registered_species?(actor.id)
      return actor.id.to_i
    end
    return nil
  end

  #--------------------------------------------------------------------------
  # ● Actor／Enemy 的 PMD key
  #--------------------------------------------------------------------------
  def self.sprite_key_for_actor(actor)
    return nil if actor == nil
    override = actor.instance_variable_get(:@cg_pmd_sprite_key_override)
    return override.to_s unless override == nil || override.to_s.empty?
    species_id = actor_species_id(actor)
    return nil if species_id == nil
    return SPECIES_SPRITES[species_id]
  end

  def self.enemy_note(enemy)
    return "" if enemy == nil
    object = enemy.respond_to?(:enemy) ? enemy.enemy : nil
    return "" if object == nil || !object.respond_to?(:note)
    return object.note.to_s
  end

  def self.enemy_species_id(enemy)
    return nil if enemy == nil || !enemy.respond_to?(:enemy_id)
    note = enemy_note(enemy)
    if note =~ /<pmd[ _-]*species\s*:\s*(\d+)>/i
      return $1.to_i
    end
    return ENEMY_SPECIES[enemy.enemy_id]
  end

  def self.sprite_key_for_enemy(enemy)
    return nil if enemy == nil
    note = enemy_note(enemy)
    if note =~ /<pmd[ _-]*sprite\s*:\s*([^>]+)>/i
      return $1.strip
    end
    if enemy.respond_to?(:enemy_id)
      direct = ENEMY_SPRITES[enemy.enemy_id]
      return direct unless direct == nil
    end
    species_id = enemy_species_id(enemy)
    return nil if species_id == nil
    return SPECIES_SPRITES[species_id]
  end

  #--------------------------------------------------------------------------
  # ● 公開整合 API
  #--------------------------------------------------------------------------
  # 捕捉完成後：CG_PMD.bind_capture(new_pet_actor, enemy_or_species_id)
  def self.bind_capture(actor, enemy_or_species_id, sprite_key = nil)
    return nil if actor == nil
    if enemy_or_species_id.respond_to?(:enemy_id)
      species_id = enemy_species_id(enemy_or_species_id)
    else
      species_id = integer_or_nil(enemy_or_species_id)
    end
    return nil if species_id == nil
    actor.cg_pmd_bind_species(species_id, sprite_key)
    return actor
  end

  # Clone 建立後：CG_PMD.bind_clone(new_actor, source_actor)
  def self.bind_clone(new_actor, source_actor)
    return nil if new_actor == nil || source_actor == nil
    new_actor.cg_pmd_copy_identity_from(source_actor)
    return new_actor
  end

  # 配種生成後：CG_PMD.bind_bred_child(child_actor, child_species_id)
  def self.bind_bred_child(actor, species_id, sprite_key = nil)
    return nil if actor == nil
    actor.cg_pmd_bind_species(species_id, sprite_key)
    return actor
  end

  # 進化完成後：CG_PMD.bind_evolution(actor, new_species_id)
  def self.bind_evolution(actor, species_id, sprite_key = nil)
    return nil if actor == nil
    actor.cg_pmd_evolve_to(species_id, sprite_key)
    return actor
  end
end

class Game_Actor < Game_Battler
  # 動態 Actor ID 與名稱都不影響這兩個欄位。
  def cg_pmd_species_id
    return CG_PMD.actor_species_id(self)
  end

  def cg_pmd_sprite_key
    return CG_PMD.sprite_key_for_actor(self)
  end

  def cg_pmd_bind_species(species_id, sprite_key = nil)
    id = CG_PMD.integer_or_nil(species_id)
    return false if id == nil
    @cg_pmd_species_id = id
    @cg_pmd_sprite_key_override = sprite_key == nil ? nil : sprite_key.to_s
    @cg_pmd_identity_version = CG_PMD::VERSION
    return true
  end

  def cg_pmd_copy_identity_from(source_actor)
    return false if source_actor == nil
    species_id = CG_PMD.actor_species_id(source_actor)
    return false if species_id == nil
    key = source_actor.instance_variable_get(:@cg_pmd_sprite_key_override)
    return cg_pmd_bind_species(species_id, key)
  end

  def cg_pmd_evolve_to(new_species_id, sprite_key = nil)
    return cg_pmd_bind_species(new_species_id, sprite_key)
  end

  def cg_pmd_clear_identity
    @cg_pmd_species_id = nil
    @cg_pmd_sprite_key_override = nil
    @cg_pmd_identity_version = nil
  end
end

class Game_Enemy < Game_Battler
  def cg_pmd_species_id
    return CG_PMD.enemy_species_id(self)
  end

  def cg_pmd_sprite_key
    return CG_PMD.sprite_key_for_enemy(self)
  end
end

class Game_Battler
  def cg_pmd_note
    return CG_PMD.enemy_note(self) if !actor?
    return ""
  end

  def cg_pmd_note_view
    note = cg_pmd_note
    if note =~ /<pmd[ _-]*view\s*:\s*([a-z_]+)>/i
      return CG_PMD.normalize_view($1)
    end
    return nil
  end

  def cg_pmd_note_direction_mode
    note = cg_pmd_note
    if note =~ /<pmd[ _-]*(?:direction|mode)\s*:\s*([a-z_]+)>/i
      return $1.downcase.to_sym
    end
    return nil
  end

  def cg_pmd_enabled?
    key = cg_pmd_sprite_key
    return false if key == nil || key.to_s.empty?
    if CG_PMD.sprite_data(key) == nil
      CG_PMD.warn_once([:missing_data, key], "CG_PMD：找不到編譯資料 #{key}，暫用原本 Battler。")
      return false
    end
    return true
  end
end
