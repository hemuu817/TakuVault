require 'rails_helper'

RSpec.describe "Assets", type: :request do
  describe "GET /index" do
    it "returns http success" do
      skip("Assets index is not implemented yet (Phase 0 / Issue #11)")
      get assets_path
      expect(response).to have_http_status(:success)
    end
  end
end
