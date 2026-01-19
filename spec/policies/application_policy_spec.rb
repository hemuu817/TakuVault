require "rails_helper"

RSpec.describe ApplicationPolicy do
  let(:user) { build_stubbed(:user) } # FactoryBotが無いなら下の代替案へ
  let(:record) { double("record") }

  subject(:policy) { described_class.new(user, record) }

  it "denies all actions by default" do
    expect(policy.index?).to be(false)
    expect(policy.show?).to be(false)
    expect(policy.create?).to be(false)
    expect(policy.update?).to be(false)
    expect(policy.destroy?).to be(false)
  end

  it "raises when user is nil (secondary defence)" do
    expect { described_class.new(nil, record) }
      .to raise_error(Pundit::NotAuthorizedError, "must be logged in")
  end
end
