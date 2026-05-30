require "rails_helper"

RSpec.describe Usages::CreateService do
  let(:user) { create(:user) }
  let(:asset) { create(:asset, user: user) }
  let(:session_record) { create(:session, user: user) }
  let(:scene) { session_record.scenes.find_by!(position: Scene::DEFAULT_POSITION) }

  it "creates one usage" do
    result = described_class.call(
      user: user,
      asset_id: asset.id,
      session_id: session_record.id,
      scene_id: scene.id,
      role: "background"
    )

    expect(result).to be_success
    expect(result.usage).to be_persisted
  end

  it "returns 422 for a duplicate usage" do
    described_class.call(
      user: user,
      asset_id: asset.id,
      session_id: session_record.id,
      scene_id: scene.id,
      role: "background"
    )

    result = described_class.call(
      user: user,
      asset_id: asset.id,
      session_id: session_record.id,
      scene_id: scene.id,
      role: "background"
    )

    expect(result).not_to be_success
    expect(result.error).to eq(:duplicate)
    expect(result.status).to eq(:unprocessable_entity)
  end

  it "fails closed when an id is malformed" do
    result = described_class.call(
      user: user,
      asset_id: "#{asset.id}abc",
      session_id: session_record.id,
      scene_id: scene.id,
      role: "background"
    )

    expect(result).not_to be_success
    expect(result.status).to eq(:not_found)
    expect(Usage.count).to eq(0)
  end
end
