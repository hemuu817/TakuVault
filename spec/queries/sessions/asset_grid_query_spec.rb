require "rails_helper"

RSpec.describe Sessions::AssetGridQuery do
  def sql_count
    count = 0
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) || payload[:cached]
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
    count
  end

  describe "#call" do
    it "returns scenes, roles, and cell usages in the expected order" do
      user = create(:user)
      session = create(:session, user: user)
      scene1 = session.scenes.find_by!(position: Scene::DEFAULT_POSITION)
      scene3 = create(:scene, session: session, name: "scene3", position: 3)
      scene2 = create(:scene, session: session, name: "scene2", position: 2)
      first_asset = create(:asset, user: user, display_name: "first.png")
      second_asset = create(:asset, user: user, display_name: "second.png")
      timestamp = Time.zone.local(2026, 1, 1, 12, 0, 0)
      first_usage = create(:usage, asset: first_asset, session: session, scene: scene2,
                                   role: :background, created_at: timestamp, updated_at: timestamp)
      second_usage = create(:usage, asset: second_asset, session: session, scene: scene2,
                                    role: :background, created_at: timestamp, updated_at: timestamp)
      standing_usage = create(:usage, asset: create(:asset, user: user), session: session, scene: scene2,
                                      role: :standing)

      result = described_class.new(session: session).call

      expect(result.scenes).to eq([ scene1, scene2, scene3 ])
      expect(result.roles).to eq(Usage::DISPLAY_ROLE_ORDER)
      expect(result.usages_for(scene2, "background")).to eq([ first_usage, second_usage ])
      expect(result.usages_for(scene2, "standing")).to eq([ standing_usage ])
      expect(result.usages_for(scene2, "cutin")).to eq([])
    end

    it "does not include usages tied to another user's asset" do
      user = create(:user)
      other_user = create(:user)
      session = create(:session, user: user)
      scene = session.scenes.find_by!(position: Scene::DEFAULT_POSITION)
      visible_asset = create(:asset, user: user)
      hidden_asset = create(:asset, user: other_user)
      visible_usage = create(:usage, asset: visible_asset, session: session, scene: scene, role: :background)
      create(:usage, asset: hidden_asset, session: session, scene: scene, role: :cutin)

      result = described_class.new(session: session).call

      expect(result.usages_for(scene, "background")).to eq([ visible_usage ])
      expect(result.usages_for(scene, "cutin")).to eq([])
    end

    it "preloads assets and attached files for loaded usages" do
      user = create(:user)
      session = create(:session, user: user)
      scene = session.scenes.find_by!(position: Scene::DEFAULT_POSITION)
      create(:usage, asset: create(:asset, user: user), session: session, scene: scene, role: :background)

      result = described_class.new(session: session).call
      usage = result.usages_for(scene, "background").first
      asset = usage.asset

      expect(usage.association(:asset)).to be_loaded
      expect(asset.association(:file_attachment)).to be_loaded
      expect(asset.file_attachment.association(:blob)).to be_loaded
    end

    it "does not add SQL queries in proportion to usage and asset counts" do
      user = create(:user)
      session = create(:session, user: user)
      scene = session.scenes.find_by!(position: Scene::DEFAULT_POSITION)
      create(:usage, asset: create(:asset, user: user), session: session, scene: scene, role: :background)

      baseline_count = sql_count { described_class.new(session: session.reload).call }

      5.times do
        create(:usage, asset: create(:asset, user: user), session: session, scene: scene, role: :standing)
      end
      expanded_count = sql_count { described_class.new(session: session.reload).call }

      expect(expanded_count).to be <= baseline_count
    end
  end
end
