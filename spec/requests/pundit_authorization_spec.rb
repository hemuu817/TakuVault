# spec/requests/pundit_authorization_spec.rb
require "rails_helper"

RSpec.describe "Pundit authorization handling", type: :request do
  let(:headers) do
    {
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                      "AppleWebKit/537.36 (KHTML, like Gecko) " \
                      "Chrome/121.0.0.0 Safari/537.36",
      "Accept" => "text/html"
    }
  end

  before do
    host! "www.example.com"

    # stub_const は per-test lifecycle の内側（before/it）で呼ぶ必要がある
    stub_const("TestPunditController", Class.new(ApplicationController) do
      skip_before_action :authenticate_user!

      def index
        raise Pundit::NotAuthorizedError
      end

      def show
        head :ok
      end

      def uncategorized
        head :ok
      end

      def dev_error
        raise Pundit::AuthorizationNotPerformedError
      end
    end)
  end

  around do |example|
    # routes はグローバルを書き換えるので ensure で必ず復旧する
    Rails.application.routes.draw do
      get "/test_pundit" => "test_pundit#index"
      get "/test_pundit_ok" => "test_pundit#show"
      get "/test_pundit_uncategorized" => "test_pundit#uncategorized"
      get "/test_pundit_dev_error" => "test_pundit#dev_error"
    end

    example.run
  ensure
    Rails.application.reload_routes!
  end

  it "returns 404 when access is denied" do
    get "/test_pundit", headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it "raises AuthorizationNotPerformedError when verify_authorized is enabled" do
    expect { get "/test_pundit_ok", headers: headers }
      .to raise_error(Pundit::AuthorizationNotPerformedError)
  end

  it "raises PolicyScopingNotPerformedError when verify_policy_scoped is enabled" do
    expect { get "/test_pundit_uncategorized", headers: headers }
      .to raise_error(Pundit::PolicyScopingNotPerformedError)
  end

  it "does not enforce verify_* when disabled" do
    allow_any_instance_of(TestPunditController)
      .to receive(:pundit_verify_enabled?)
      .and_return(false)

    get "/test_pundit_ok", headers: headers
    expect(response).to have_http_status(:ok)
  end

  it "does not swallow developer errors (AuthorizationNotPerformedError)" do
    expect { get "/test_pundit_dev_error", headers: headers }
      .to raise_error(Pundit::AuthorizationNotPerformedError)
  end
end
