# spec/support/capybara.rb
require "capybara/rspec"
require "selenium/webdriver"

Capybara.server_host = "localhost"

Capybara.register_driver :taku_vault_selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new") unless ENV["CHROME_HEADLESS"] == "false"
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=1400,1400")
  options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?

  service_options = {}
  service_options[:path] = ENV["CHROMEDRIVER_PATH"] if ENV["CHROMEDRIVER_PATH"].present?
  service = Selenium::WebDriver::Service.chrome(**service_options)

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, service: service)
end

RSpec.configure do |config|
  config.before(:each, type: :system) do |example|
    if example.metadata[:js]
      driven_by :taku_vault_selenium_chrome_headless
    else
      driven_by :rack_test
    end
  end
end
