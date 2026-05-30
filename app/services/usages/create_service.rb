module Usages
  class CreateService
    Result = Struct.new(:success, :usage, :error, :status, keyword_init: true) do
      def success?
        success
      end
    end

    def self.call(user:, asset_id:, session_id:, scene_id:, role:)
      new(
        user: user,
        asset_id: asset_id,
        session_id: session_id,
        scene_id: scene_id,
        role: role
      ).call
    end

    def initialize(user:, asset_id:, session_id:, scene_id:, role:)
      @user = user
      @raw_asset_id = asset_id
      @raw_session_id = session_id
      @raw_scene_id = scene_id
      @role = role.to_s
    end

    def call
      asset_id = parse_id(raw_asset_id)
      session_id = parse_id(raw_session_id)
      scene_id = parse_id(raw_scene_id)
      return failure(:not_found, :not_found) unless asset_id && session_id && scene_id
      return failure(:invalid_role, :unprocessable_entity) unless Usage.roles.key?(role)

      asset = Pundit.policy_scope!(user, Asset).find_by(id: asset_id)
      session = Pundit.policy_scope!(user, Session).find_by(id: session_id)
      scene = Pundit.policy_scope!(user, Scene).find_by(id: scene_id, session_id: session_id)
      return failure(:not_found, :not_found) unless asset && session && scene

      if Usage.exists?(asset_id: asset.id, session_id: session.id, scene_id: scene.id, role: Usage.roles.fetch(role))
        return failure(:duplicate, :unprocessable_entity)
      end

      usage = Usage.create!(
        asset: asset,
        session: session,
        scene: scene,
        role: role
      )
      Result.new(success: true, usage: usage, error: nil, status: :see_other)
    rescue ActiveRecord::RecordNotUnique
      failure(:duplicate, :unprocessable_entity)
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::NotNullViolation
      failure(:invalid_reference, :unprocessable_entity)
    end

    private

    attr_reader :user, :raw_asset_id, :raw_session_id, :raw_scene_id, :role

    def parse_id(value)
      value = value.to_s
      return nil unless value.match?(/\A[1-9]\d*\z/)

      value.to_i
    end

    def failure(error, status)
      Result.new(success: false, usage: nil, error: error, status: status)
    end
  end
end
