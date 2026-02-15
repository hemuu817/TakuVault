require "rails_helper"

RSpec.describe ApplicationController do
  subject(:controller_instance) { described_class.new }

  describe "#pundit_verify_enabled?" do
    let(:original_env) { ENV["PUNDIT_VERIFY"] }

    after do
      ENV["PUNDIT_VERIFY"] = original_env
      allow(Rails).to receive(:env).and_call_original
    end

    it "returns true in test env regardless of PUNDIT_VERIFY" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("test"))
      ENV["PUNDIT_VERIFY"] = "false"

      expect(controller_instance.send(:pundit_verify_enabled?)).to be(true)
    end

    it "returns false in production when PUNDIT_VERIFY is unset" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      ENV.delete("PUNDIT_VERIFY")

      expect(controller_instance.send(:pundit_verify_enabled?)).to be(false)
    end

    it "casts PUNDIT_VERIFY in production" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      ENV["PUNDIT_VERIFY"] = "true"

      expect(controller_instance.send(:pundit_verify_enabled?)).to be(true)
    end
  end
end
