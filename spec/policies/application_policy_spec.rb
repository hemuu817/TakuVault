require "rails_helper"

RSpec.describe ApplicationPolicy do
  subject(:policy) { described_class.new(user, record) }

  let(:user) { nil }
  let(:record) { nil }

  it "denies all actions by default" do
    expect(policy.index?).to be(false)
    expect(policy.show?).to be(false)
    expect(policy.create?).to be(false)
    expect(policy.new?).to be(false)
    expect(policy.update?).to be(false)
    expect(policy.edit?).to be(false)
    expect(policy.destroy?).to be(false)
  end

  it "resolves to an empty scope by default" do
    scope = described_class::Scope.new(user, User.all)
    expect(scope.resolve).to be_a(ActiveRecord::Relation)
    expect(scope.resolve).to be_empty
  end
end
