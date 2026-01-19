require "rails_helper"

RSpec.describe AssetPolicy, type: :policy do
  let(:owner) { create(:user) }
  let(:other) { create(:user) }
  let(:asset) { create(:asset, user: owner, original_filename: "owned.png", display_name: "owned.png") }


  describe "permissions" do
    subject(:policy) { described_class.new(user, asset) }

    context "with owner" do
      let(:user) { owner }

      it { expect(policy.index?).to be(true) }
      it { expect(policy.show?).to be(true) }
      it { expect(policy.create?).to be(true) }
      it { expect(policy.update?).to be(true) }
      it { expect(policy.destroy?).to be(true) }
    end

    context "with other user" do
      let(:user) { other }

      it { expect(policy.index?).to be(true) }
      it { expect(policy.show?).to be(false) }
      it { expect(policy.create?).to be(false) }
      it { expect(policy.update?).to be(false) }
      it { expect(policy.destroy?).to be(false) }
    end
  end

  describe "scope" do
    it "returns only owned assets" do
      owned = asset
      other_asset = create(:asset, user: other, original_filename: "other.png", display_name: "other.png")

      scope = described_class::Scope.new(owner, Asset.all).resolve

      expect(scope).to contain_exactly(owned)
      expect(scope).not_to include(other_asset)
    end
  end
end
