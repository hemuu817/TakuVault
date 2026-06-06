module Sessions
  class AssetGridQuery
    Result = Struct.new(:scenes, :roles, :usages_by_cell, keyword_init: true) do
      def usages_for(scene, role)
        usages_by_cell.fetch([ scene.id, role ], [])
      end
    end

    def initialize(session:)
      @session = session
    end

    def call
      scenes = session.scenes.order(:position).to_a
      roles = Usage.roles.keys
      usages = session.usages
        .joins(:asset)
        .includes(asset: { file_attachment: :blob })
        .where(assets: { user_id: session.user_id })
        .order(:created_at, :id)
        .to_a

      Result.new(
        scenes: scenes,
        roles: roles,
        usages_by_cell: usages.group_by { |usage| [ usage.scene_id, usage.role ] }
      )
    end

    private

    attr_reader :session
  end
end
