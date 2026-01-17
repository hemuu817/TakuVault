# spec/support/capybara.rb
require "capybara/rspec"

RSpec.configure do |config|
  # system spec はブラウザを使わない rack_test で回す
  config.before(:each, type: :system) do
    driven_by :rack_test
  end
end
