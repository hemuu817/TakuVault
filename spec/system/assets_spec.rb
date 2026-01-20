require "rails_helper"

RSpec.describe "Assets", type: :system do
  let(:modern_user_agent) do
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"
  end

  let(:user) { create(:user, email: "system@example.com") }

  before do
    page.driver.header "User-Agent", modern_user_agent
  end

  it "複数選択アップロードで複数Assetが作成される" do
    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "password"
    click_button "Log in"

    visit new_asset_path
    attach_file "asset_files", [
      Rails.root.join("spec/fixtures/files/valid.png"),
      Rails.root.join("spec/fixtures/files/valid2.png")
    ]
    click_button "アップロード"

    expect(page).to have_current_path(new_asset_path, ignore_query: true)
    expect(page).to have_content("アップロードしました")

    click_link "一覧へ戻る"

    expect(page).to have_content("素材一覧")
    expect(page).to have_content("valid.png")
    expect(page).to have_content("valid2.png")
  end
end
