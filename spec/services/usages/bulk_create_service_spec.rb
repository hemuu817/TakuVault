require "rails_helper"

RSpec.describe Usages::BulkCreateService do
  let(:user) { create(:user) }
  let(:session_record) { create(:session, user: user) }
  let(:scene) { session_record.scenes.find_by!(position: Scene::DEFAULT_POSITION) }

  it "creates usages for multiple owned assets" do
    assets = create_list(:asset, 2, user: user)

    result = described_class.call(
      user: user,
      asset_ids: assets.map(&:id),
      session_id: session_record.id,
      scene_id: scene.id,
      role: "background"
    )

    expect(result).to be_success
    expect(result.created_count).to eq(2)
    expect(result.skipped_duplicate_count).to eq(0)
    expect(Usage.count).to eq(2)
  end

  it "skips duplicate usages idempotently" do
    assets = create_list(:asset, 2, user: user)
    described_class.call(
      user: user,
      asset_ids: assets.map(&:id),
      session_id: session_record.id,
      scene_id: scene.id,
      role: "background"
    )

    result = described_class.call(
      user: user,
      asset_ids: assets.map(&:id),
      session_id: session_record.id,
      scene_id: scene.id,
      role: "background"
    )

    expect(result).to be_success
    expect(result.created_count).to eq(0)
    expect(result.skipped_duplicate_count).to eq(2)
    expect(result.skipped_assets.map { |asset| asset[:id] }).to match_array(assets.map(&:id))
    expect(Usage.count).to eq(2)
  end

  it "fails closed when an asset belongs to another user" do
    asset = create(:asset, user: user)
    other_asset = create(:asset)

    result = described_class.call(
      user: user,
      asset_ids: [ asset.id, other_asset.id ],
      session_id: session_record.id,
      scene_id: scene.id,
      role: "background"
    )

    expect(result).not_to be_success
    expect(result.status).to eq(:not_found)
    expect(Usage.count).to eq(0)
  end

  it "fails closed when an asset id is malformed" do
    asset = create(:asset, user: user)

    result = described_class.call(
      user: user,
      asset_ids: [ "#{asset.id}abc" ],
      session_id: session_record.id,
      scene_id: scene.id,
      role: "background"
    )

    expect(result).not_to be_success
    expect(result.status).to eq(:not_found)
    expect(Usage.count).to eq(0)
  end

  it "fails closed when scene does not belong to the selected session" do
    asset = create(:asset, user: user)
    other_session = create(:session, user: user)
    other_scene = other_session.scenes.find_by!(position: Scene::DEFAULT_POSITION)

    result = described_class.call(
      user: user,
      asset_ids: [ asset.id ],
      session_id: session_record.id,
      scene_id: other_scene.id,
      role: "background"
    )

    expect(result).not_to be_success
    expect(result.status).to eq(:not_found)
    expect(Usage.count).to eq(0)
  end

  it "rejects an invalid role" do
    asset = create(:asset, user: user)

    result = described_class.call(
      user: user,
      asset_ids: [ asset.id ],
      session_id: session_record.id,
      scene_id: scene.id,
      role: "invalid"
    )

    expect(result).not_to be_success
    expect(result.status).to eq(:unprocessable_entity)
  end
end
