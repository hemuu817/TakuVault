module Usages
  class BulkCreateService
    Result = Struct.new(
      :success,
      :created_count,
      :skipped_duplicate_count,
      :skipped_assets,
      :error,
      :status,
      keyword_init: true
    ) do
      def success?
        success
      end
    end

    def self.call(user:, asset_ids:, session_id:, scene_id:, role:)
      new(
        user: user,
        asset_ids: asset_ids,
        session_id: session_id,
        scene_id: scene_id,
        role: role
      ).call
    end

    def initialize(user:, asset_ids:, session_id:, scene_id:, role:)
      @user = user
      @raw_asset_ids = Array(asset_ids).reject(&:blank?)
      @raw_session_id = session_id
      @raw_scene_id = scene_id
      @role = role.to_s
    end

    def call
      asset_ids = parse_ids(raw_asset_ids)
      session_id = parse_id(raw_session_id)
      scene_id = parse_id(raw_scene_id)
      return failure(:not_found, :not_found) unless asset_ids && session_id && scene_id
      return failure(:asset_required, :unprocessable_entity) if asset_ids.empty?
      return failure(:invalid_role, :unprocessable_entity) unless Usage.roles.key?(role)

      assets = Pundit.policy_scope!(user, Asset).where(id: asset_ids).order(:id).to_a
      return failure(:not_found, :not_found) unless assets.size == asset_ids.size

      session = Pundit.policy_scope!(user, Session).find_by(id: session_id)
      scene = Pundit.policy_scope!(user, Scene).find_by(id: scene_id, session_id: session_id)
      return failure(:not_found, :not_found) unless session && scene

      now = Time.current
      existing_asset_ids = Usage.where(
        asset_id: asset_ids,
        session_id: session.id,
        scene_id: scene.id,
        role: Usage.roles.fetch(role)
      ).pluck(:asset_id)
      existing_asset_id_set = existing_asset_ids.index_with(true)
      rows = assets.reject { |asset| existing_asset_id_set.include?(asset.id) }.map do |asset|
        {
          asset_id: asset.id,
          session_id: session.id,
          scene_id: scene.id,
          role: Usage.roles.fetch(role),
          created_at: now,
          updated_at: now
        }
      end

      result = rows.empty? ? nil : Usage.insert_all(
        rows,
        unique_by: :index_usages_on_asset_id_and_session_id_and_scene_id_and_role
      )
      created_count = result ? result.rows.size : 0
      skipped_duplicate_count = asset_ids.size - created_count

      Result.new(
        success: true,
        created_count: created_count,
        skipped_duplicate_count: skipped_duplicate_count,
        skipped_assets: skipped_assets(assets, existing_asset_id_set),
        error: nil,
        status: :see_other
      )
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::NotNullViolation
      failure(:invalid_reference, :unprocessable_entity)
    end

    private

    attr_reader :user, :raw_asset_ids, :raw_session_id, :raw_scene_id, :role

    def parse_ids(values)
      parsed = values.map { |value| parse_id(value) }
      return nil if parsed.any?(&:nil?)

      parsed.uniq
    end

    def parse_id(value)
      value = value.to_s
      return nil unless value.match?(/\A[1-9]\d*\z/)

      value.to_i
    end

    def skipped_assets(assets, existing_asset_id_set)
      assets.select { |asset| existing_asset_id_set.include?(asset.id) }.map do |asset|
        {
          id: asset.id,
          display_name: asset.display_name,
          original_filename: asset.original_filename
        }
      end
    end

    def failure(error, status)
      Result.new(
        success: false,
        created_count: 0,
        skipped_duplicate_count: 0,
        skipped_assets: [],
        error: error,
        status: status
      )
    end
  end
end
