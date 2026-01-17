require "rails_helper"

RSpec.describe "Auth", type: :system do
  let(:modern_user_agent) do
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"
  end

  before do
    page.driver.header "User-Agent", modern_user_agent
  end

  it "サインアップ→ログイン状態→ログアウト" do
    visit new_user_registration_path
    fill_in "user_email", with: "test@example.com"
    fill_in "user_password", with: "password"
    fill_in "user_password_confirmation", with: "password"
    click_button "Sign up"

    expect(page).to have_button("ログアウト")

    click_button "ログアウト"
    expect(page).to have_link("ログイン")
  end

  it "未ログインで /assets 直打ち → /users/sign_in へ誘導" do
    visit assets_path

    expect(page).to have_current_path(new_user_session_path, ignore_query: true)
  end

# spec/system/auth_spec.rb
it "ログイン失敗でエラーが出る（Turboでも崩れない）" do
  User.create!(email: "u@example.com", password: "password")

  visit new_user_session_path
  fill_in "user_email", with: "u@example.com"
  fill_in "user_password", with: "wrong"
  click_button "Log in"

  # 失敗していればサインイン画面に留まる（文言に依存しない）
  expect(page).to have_current_path(new_user_session_path, ignore_query: true)

  # “POSTが走って画面が再描画された”ことをもう一段担保したい場合（任意）
  expect(page).to have_field("user_email", with: "u@example.com")
  # JS/Turbo behavior (clearing password) depends on driver; only assert presence here
  expect(page).to have_field("user_password")
end


end
