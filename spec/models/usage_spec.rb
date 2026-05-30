require "rails_helper"

RSpec.describe Usage, type: :model do
  it "enforces allowed role values at the database level" do
    usage = create(:usage)

    expect {
      Usage.insert_all!([
        {
          asset_id: usage.asset.id,
          session_id: usage.session.id,
          scene_id: usage.scene.id,
          role: 99,
          created_at: Time.current,
          updated_at: Time.current
        }
      ])
    }.to raise_error(ActiveRecord::StatementInvalid)
  end
end
