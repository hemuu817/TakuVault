module Usages
  class UpdateService
    Result = Struct.new(:success, :usage, :error, :status, keyword_init: true) do
      def success?
        success
      end
    end

    def self.call(user:, usage:, scene_id:, role:)
      new(user: user, usage: usage, scene_id: scene_id, role: role).call
    end

    def initialize(user:, usage:, scene_id:, role:)
      @user = user
      @usage = usage
      @raw_scene_id = scene_id
      @role = role.to_s
    end

    def call
      scene_id = parse_id(raw_scene_id)
      return failure(:not_found, :not_found) unless scene_id
      return failure(:invalid_role, :unprocessable_entity) unless Usage.roles.key?(role)

      scene = Pundit.policy_scope!(user, Scene).find_by(id: scene_id, session_id: usage.session_id)
      return failure(:not_found, :not_found) unless scene

      session = usage.session
      if duplicate_usage?(session, scene)
        return failure(:duplicate, :unprocessable_entity)
      end

      usage.update!(
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

    attr_reader :user, :usage, :raw_scene_id, :role

    def duplicate_usage?(session, scene)
      Usage.where(
        asset_id: usage.asset_id,
        session_id: session.id,
        scene_id: scene.id,
        role: Usage.roles.fetch(role)
      ).where.not(id: usage.id).exists?
    end

    def parse_id(value)
      value = value.to_s
      return nil unless value.match?(/\A[1-9]\d*\z/)

      value.to_i
    end

    def failure(error, status)
      Result.new(success: false, usage: usage, error: error, status: status)
    end
  end
end
