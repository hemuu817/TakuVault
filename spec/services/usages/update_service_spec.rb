require "rails_helper"

RSpec.describe Usages::UpdateService do
  let(:user) { create(:user) }
  let(:asset) { create(:asset, user: user) }
  let(:session_record) { create(:session, user: user) }
  let(:scene) { session_record.scenes.find_by!(position: Scene::DEFAULT_POSITION) }

  it "usageを各追加roleへ更新できる" do
    %w[standing panel sound_effect].each do |role|
      usage = create(:usage, asset: asset, session: session_record, scene: scene, role: :background)

      result = described_class.call(user: user, usage: usage, scene_id: scene.id, role: role)

      expect(result).to be_success
      expect(usage.reload.role).to eq(role)
    end
  end

  it "不正なroleなら更新を拒否する" do
    usage = create(:usage, asset: asset, session: session_record, scene: scene, role: :background)

    result = described_class.call(user: user, usage: usage, scene_id: scene.id, role: "invalid")

    expect(result).not_to be_success
    expect(result.status).to eq(:unprocessable_entity)
    expect(usage.reload.role).to eq("background")
  end
end
