require "rails_helper"

RSpec.describe "framework defaults" do
  it "enables the Rails 8.0 regular expression timeout" do
    expect(Regexp.timeout).to eq(1)
  end

  it "enables strict HTTP freshness checks" do
    expect(Rails.application.config.action_dispatch.strict_freshness).to be(true)
  end

  it "preserves a TimeWithZone receiver's timezone when converting to Time" do
    zone = ActiveSupport::TimeZone["Asia/Tokyo"]
    converted = zone.local(2026, 6, 21, 12).to_time

    expect(converted.utc_offset).to eq(zone.utc_offset)
    expect(converted.zone).to eq(zone)
  end

  it "raises on path-relative redirects" do
    expect(Rails.application.config.action_controller.action_on_path_relative_redirect).to eq(:raise)
  end

  it "does not escape JSON responses by default" do
    expect(Rails.application.config.action_controller.escape_json_responses).to be(false)
  end

  it "omits autocomplete attributes from generated hidden fields" do
    expect(Rails.application.config.action_view.remove_hidden_field_autocomplete).to be(true)
  end

  it "uses the Ruby Action View render tracker" do
    expect(Rails.application.config.action_view.render_tracker).to eq(:ruby)
  end

  it "raises when required finder order columns are missing" do
    expect(Rails.application.config.active_record.raise_on_missing_required_finder_order_columns).to be(true)
  end

  it "does not escape JavaScript separators in JSON" do
    expect(Rails.application.config.active_support.escape_js_separators_in_json).to be(false)
  end

  it "disables YJIT in the local test environment" do
    expect(Rails.env.local?).to be(true)
    expect(Rails.application.config.yjit).to be(false)
  end
end
