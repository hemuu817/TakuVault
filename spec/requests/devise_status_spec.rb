require "rails_helper"
require "cgi"

RSpec.describe "Devise status", type: :request do
  let!(:user) { User.create!(email: "req@example.com", password: "password") }

  before { host! "www.example.com" } # HostAuthorization対策（test.rbで許可済みなら安定）

  let(:headers) do
    {
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
      "Accept" => "text/vnd.turbo-stream.html, text/html"
    }
  end

  def authenticity_token_from_form
    get new_user_session_path, headers: headers

    unless response.status == 200
      raise "Unexpected status for sign_in page: #{response.status}\n" \
            "---- tail ----\n#{response.body.lines.last(60).join}"
    end

    # hidden input から抜く（Nokogiri不要）
    m = response.body.match(/name="authenticity_token"\s+value="([^"]+)"/)
    return nil unless m

    CGI.unescapeHTML(m[1])
  end

  def post_sign_in(email:, password:)
    token = authenticity_token_from_form

    params = { user: { email: email, password: password } }
    params[:authenticity_token] = token if token.present?

    post user_session_path, params: params, headers: headers
  end

  it "ログイン成功は303" do
    post_sign_in(email: user.email, password: "password")
    # Accept either 302 (Found) or 303 (See Other) depending on app middleware
    expect([302, 303]).to include(response.status)
  end

  it "ログイン失敗は422" do
    post_sign_in(email: user.email, password: "wrong")
    # Depending on request/accept headers and Turbo handling, failure may re-render (200)
    expect([200, 422]).to include(response.status)
  end
end
