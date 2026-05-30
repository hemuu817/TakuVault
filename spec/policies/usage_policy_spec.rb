require "rails_helper"

RSpec.describe UsagePolicy do
  describe "Scope" do
    it "returns only usages whose asset and scene session both belong to the user" do
      user = create(:user)
      other = create(:user)
      asset = create(:asset, user: user)
      session_record = create(:session, user: user)
      scene = session_record.scenes.find_by!(position: Scene::DEFAULT_POSITION)
      owned_usage = create(:usage, asset: asset, session: session_record, scene: scene)
      create(:usage, asset: create(:asset, user: other))

      resolved = Pundit.policy_scope!(user, Usage)

      expect(resolved).to contain_exactly(owned_usage)
    end
  end
end
