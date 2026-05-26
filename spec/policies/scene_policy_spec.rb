require "rails_helper"

RSpec.describe ScenePolicy, type: :policy do
  let(:owner) { create(:user) }
  let(:other) { create(:user) }
  let(:session_record) { create(:session, user: owner) }
  let(:scene) { create(:scene, session: session_record, position: 2) }
  let(:default_scene) { session_record.scenes.find_by!(position: 1) }

  describe "permissions" do
    context "with owner" do
      subject(:policy) { described_class.new(owner, scene) }

      it { expect(policy.index?).to be(true) }
      it { expect(policy.show?).to be(true) }
      it { expect(policy.create?).to be(true) }
      it { expect(policy.update?).to be(true) }
      it { expect(policy.destroy?).to be(true) }
    end

    context "with other user" do
      subject(:policy) { described_class.new(other, scene) }

      it { expect(policy.index?).to be(true) }
      it { expect(policy.show?).to be(false) }
      it { expect(policy.create?).to be(false) }
      it { expect(policy.update?).to be(false) }
      it { expect(policy.destroy?).to be(false) }
    end

    it "does not allow default_scene destroy" do
      policy = described_class.new(owner, default_scene)

      expect(policy.destroy?).to be(false)
    end
  end

  describe "scope" do
    it "returns only scenes through owned sessions" do
      owned = scene
      other_scene = create(:scene, session: create(:session, user: other), position: 2)

      scope = described_class::Scope.new(owner, Scene.all).resolve

      expect(scope).to include(owned)
      expect(scope).not_to include(other_scene)
    end
  end
end
