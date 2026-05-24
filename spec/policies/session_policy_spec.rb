require "rails_helper"

RSpec.describe SessionPolicy, type: :policy do
  let(:owner) { create(:user) }
  let(:other) { create(:user) }
  let(:session_record) { create(:session, user: owner) }

  describe "permissions" do
    subject(:policy) { described_class.new(user, session_record) }

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
    it "returns only owned sessions" do
      owned = session_record
      other_session = create(:session, user: other)

      scope = described_class::Scope.new(owner, Session.all).resolve

      expect(scope).to contain_exactly(owned)
      expect(scope).not_to include(other_session)
    end
  end
end
