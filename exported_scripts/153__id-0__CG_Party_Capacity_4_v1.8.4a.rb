# RMVX_SCRIPT_INDEX: 153
# RMVX_SCRIPT_ID: 0
# RMVX_SCRIPT_NAME: CG Party Capacity 4 v1.8.4a
# RMVX_SOURCE_SHA256: a2472664e174cbc0b68949998b0924da66a939767c29a8732fc1f9319c2a245f

#==============================================================================
# ■ CG Party Capacity 4 v1.8.4a
#------------------------------------------------------------------------------
# RPG Maker VX / RGSS2 / Ruby 1.8
# 專案：CG Pet Battle Prototype
#
# 【目的】
#  1. 正式戰鬥隊伍改為 4 名，即兩組「人物＋寵物」。
#  2. 最終強制 Game_Party 與 Tankentai 的參戰上限皆為 4。
#  3. 舊存檔若仍保存 5～6 名成員，保留隊伍順序最前方四名。
#  4. 固定夥伴仍依主人同步，但不會突破四人上限。
#  5. Actor 3／Actor 106 等第三組資料不刪除，留待後續隊伍編成使用。
#
# 【位置】
#  取代舊 CG Party Capacity 6 v1.8.2，位於所有隊伍腳本下方。
#==============================================================================

$imported = {} if $imported == nil
$imported["ALBERT_CG_PartyCapacity4_1_8_4a"] = true

module ALBERT_CG
  remove_const(:PARTY_MEMBER_LIMIT) if const_defined?(:PARTY_MEMBER_LIMIT)
  PARTY_MEMBER_LIMIT = 4

  def self.cg_v184a_apply_party_limits
    begin
      Game_Party.send(:remove_const, :MAX_MEMBERS) if
        Game_Party.const_defined?(:MAX_MEMBERS)
      Game_Party.const_set(:MAX_MEMBERS, PARTY_MEMBER_LIMIT)
    rescue
    end
    begin
      if defined?(N01)
        N01.send(:remove_const, :MAX_MEMBER) if N01.const_defined?(:MAX_MEMBER)
        N01.const_set(:MAX_MEMBER, PARTY_MEMBER_LIMIT)
      end
    rescue
    end
  end
end

ALBERT_CG.cg_v184a_apply_party_limits

class Game_Party < Game_Unit
  alias albert_cg_v184a_capacity_initialize initialize
  def initialize
    ALBERT_CG.cg_v184a_apply_party_limits
    albert_cg_v184a_capacity_initialize
    cg_v184a_trim_to_limit!
  end

  def cg_v184a_valid_actor_id?(actor_id)
    actor_id = actor_id.to_i
    return true if $data_actors != nil && $data_actors[actor_id] != nil
    return true if $game_actors != nil && $game_actors.respond_to?(:cg_pet) &&
                   $game_actors.cg_pet(actor_id) != nil
    return false
  rescue
    return false
  end

  def cg_v184a_raw_insert_actor(actor_id, insert_index = nil)
    @actors = [] if @actors == nil
    actor_id = actor_id.to_i
    return true if @actors.include?(actor_id)
    return false unless cg_v184a_valid_actor_id?(actor_id)
    return false if @actors.size >= ALBERT_CG::PARTY_MEMBER_LIMIT
    if insert_index == nil || insert_index < 0 || insert_index > @actors.size
      @actors.push(actor_id)
    else
      @actors.insert(insert_index, actor_id)
    end
    return true
  end

  def cg_v184a_ensure_fixed_partner(owner_id)
    return false unless respond_to?(:cg_fixed_partner_pet_actor_id)
    owner_id = owner_id.to_i
    pet_id = cg_fixed_partner_pet_actor_id(owner_id)
    return false if pet_id == nil || pet_id.to_i <= 0
    @actors = [] if @actors == nil
    return false unless @actors.include?(owner_id)

    return true if @actors.include?(pet_id.to_i)
    return false if @actors.size >= ALBERT_CG::PARTY_MEMBER_LIMIT

    owner_index = @actors.index(owner_id)
    inserted = cg_v184a_raw_insert_actor(pet_id.to_i,
      owner_index == nil ? nil : owner_index + 1)
    if inserted && respond_to?(:cg_set_fixed_partner_deployed)
      cg_set_fixed_partner_deployed(owner_id, true)
    end
    return inserted
  end

  # 舊存檔或舊測試腳本可能保存六名隊員。新版只保留前四名，
  # 以維持主人／寵物既有排列，不在載入時任意重排玩家隊伍。
  def cg_v184a_trim_to_limit!
    @actors = [] if @actors == nil
    limit = ALBERT_CG::PARTY_MEMBER_LIMIT
    return false if @actors.size <= limit
    removed = @actors[limit, @actors.size - limit] || []
    @actors = @actors[0, limit]

    if respond_to?(:cg_set_fixed_partner_deployed) &&
       defined?(ALBERT_CG::FIXED_PARTNER_PET_ACTORS)
      ALBERT_CG::FIXED_PARTNER_PET_ACTORS.each do |owner_id, pet_id|
        if removed.include?(owner_id.to_i) || removed.include?(pet_id.to_i)
          cg_set_fixed_partner_deployed(owner_id.to_i, false)
        end
      end
    end

    cg_v056_refresh_active_cache if respond_to?(:cg_v056_refresh_active_cache)
    $game_player.refresh if $game_player != nil
    $party_change = true
    return true
  rescue
    return false
  end

  alias albert_cg_v184a_capacity_add_actor add_actor
  def add_actor(actor_id)
    ALBERT_CG.cg_v184a_apply_party_limits
    actor_id = actor_id.to_i
    before = @actors == nil ? [] : @actors.clone

    # 走完原本的主人／Clone／固定夥伴同步鏈。
    result = albert_cg_v184a_capacity_add_actor(actor_id)

    inserted = cg_v184a_raw_insert_actor(actor_id)
    cg_v184a_ensure_fixed_partner(actor_id)
    cg_sync_fixed_partner_pets! if respond_to?(:cg_sync_fixed_partner_pets!)
    cg_v184a_trim_to_limit!

    after = @actors == nil ? [] : @actors
    if before != after || inserted
      $game_player.refresh if $game_player != nil
      $party_change = true
      cg_v056_refresh_active_cache if respond_to?(:cg_v056_refresh_active_cache)
    end
    return result
  end

  alias albert_cg_v184a_capacity_members members
  def members
    ALBERT_CG.cg_v184a_apply_party_limits
    cg_sync_fixed_partner_pets! if respond_to?(:cg_sync_fixed_partner_pets!)
    cg_v184a_trim_to_limit!
    return albert_cg_v184a_capacity_members
  end

  # 開發檢查：事件腳本可用 p $game_party.cg_v184a_party_snapshot
  def cg_v184a_party_snapshot
    @actors = [] if @actors == nil
    result = []
    for actor_id in @actors
      actor = nil
      if $game_actors != nil && $game_actors.respond_to?(:cg_pet)
        actor = $game_actors.cg_pet(actor_id)
      end
      actor = $game_actors[actor_id] if actor == nil && $game_actors != nil
      result.push([actor_id, actor == nil ? "?" : actor.name])
    end
    return result
  end
end

class Scene_Title < Scene_Base
  alias albert_cg_v184a_capacity_load_database load_database
  def load_database
    albert_cg_v184a_capacity_load_database
    ALBERT_CG.cg_v184a_apply_party_limits
  end

  alias albert_cg_v184a_capacity_load_bt_database load_bt_database
  def load_bt_database
    albert_cg_v184a_capacity_load_bt_database
    ALBERT_CG.cg_v184a_apply_party_limits
  end
end
