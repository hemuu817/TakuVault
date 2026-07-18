require "rails_helper"

RSpec.describe "未整理Assetのkind連動UI", type: :system, js: true do
  include Warden::Test::Helpers

  let(:user) { create(:user, email: "uncategorized-system@example.com") }

  def log_in
    login_as user, scope: :user
  end

  def create_asset(name:, kind:, created_at:)
    asset = create(:asset, user: user, display_name: name, original_filename: "#{name}.png")
    asset.update_columns(kind: Asset.kinds.fetch(kind), created_at: created_at)
    asset
  end

  def row_for(asset)
    find("[data-asset-id='#{asset.id}']")
  end

  def checkbox_for(asset)
    find("#asset_ids_#{asset.id}")
  end

  def displayed_asset_ids
    all("[data-uncategorized-kind-target~='row']").map { |row| row["data-asset-id"].to_i }
  end

  def available_role_values
    page.evaluate_script(<<~JS)
      Array.from(document.querySelector("select[data-uncategorized-kind-target='roleSelect']").options)
        .filter((option) => option.value !== "" && !option.hidden && !option.disabled)
        .map((option) => option.value)
    JS
  end

  def role_select
    find("select[data-uncategorized-kind-target='roleSelect']")
  end

  before do
    base_time = Time.zone.parse("2026-07-16 12:00:00")
    @image_old = create_asset(name: "image-old", kind: "image", created_at: base_time)
    @image_new = create_asset(name: "image-new", kind: "image", created_at: base_time + 1.hour)
    @audio = create_asset(name: "audio", kind: "audio", created_at: base_time + 2.hours)
    @other = create_asset(name: "other", kind: "other", created_at: base_time + 3.hours)
    @initial_order = [ @image_new.id, @image_old.id, @audio.id, @other.id ]

    log_in
    visit uncategorized_assets_path
  end

  after do
    Warden.test_reset!
  end

  it "imageを基準kindにして異種kindとrole候補を制御し、全解除で初期化する" do
    expect(displayed_asset_ids).to eq(@initial_order)
    expect(available_role_values).to eq(%w[ background standing cutin panel bgm sound_effect other ])

    role_select.select("背景")
    checkbox_for(@image_old).check

    expect(checkbox_for(@image_new)).not_to be_disabled
    expect(checkbox_for(@audio)).to be_disabled
    expect(checkbox_for(@other)).to be_disabled
    expect(row_for(@audio)[:class]).to include("opacity-40")
    expect(row_for(@other)[:class]).to include("opacity-40")
    expect(displayed_asset_ids.first(2)).to eq([ @image_new.id, @image_old.id ])
    expect(available_role_values).to eq(%w[ background standing cutin panel other ])
    expect(role_select.value).to eq("background")

    checkbox_for(@image_new).check
    checkbox_for(@image_old).uncheck

    expect(checkbox_for(@audio)).to be_disabled
    expect(displayed_asset_ids.first(2)).to eq([ @image_new.id, @image_old.id ])

    checkbox_for(@image_new).uncheck

    expect(checkbox_for(@audio)).not_to be_disabled
    expect(checkbox_for(@other)).not_to be_disabled
    expect(row_for(@audio)[:class]).not_to include("opacity-40")
    expect(displayed_asset_ids).to eq(@initial_order)
    expect(available_role_values).to eq(%w[ background standing cutin panel bgm sound_effect other ])
    expect(role_select.value).to eq("background")
  end

  it "候補外roleだけを解除し、audioとotherの候補を切り替える" do
    checkbox_for(@image_new).check
    expect(role_select.value).to eq("")
    checkbox_for(@image_new).uncheck

    role_select.select("BGM")
    checkbox_for(@image_new).check

    expect(role_select.value).to eq("")
    expect(available_role_values).to eq(%w[ background standing cutin panel other ])

    checkbox_for(@image_new).uncheck
    role_select.select("その他")
    checkbox_for(@audio).check

    expect(displayed_asset_ids.first).to eq(@audio.id)
    expect(available_role_values).to eq(%w[ bgm sound_effect other ])
    expect(role_select.value).to eq("other")

    checkbox_for(@audio).uncheck
    checkbox_for(@other).check

    expect(displayed_asset_ids.first).to eq(@other.id)
    expect(available_role_values).to eq(%w[ other ])
    expect(role_select.value).to eq("other")
    expect(page).to have_button("詳細を一括作成", disabled: false)
  end

  it "Turboキャッシュ後の復元状態からUIを再構築する" do
    role_select.select("その他")
    checkbox_for(@audio).check

    visit assets_path
    page.go_back

    restored_audio = checkbox_for(@audio)
    if restored_audio.checked?
      expect(restored_audio).not_to be_disabled
      expect(checkbox_for(@image_new)).to be_disabled
      expect(row_for(@image_new)[:class]).to include("opacity-40")
      expect(displayed_asset_ids.first).to eq(@audio.id)
      expect(available_role_values).to eq(%w[ bgm sound_effect other ])
      expect(role_select.value).to eq("other")
    else
      expect(displayed_asset_ids).to eq(@initial_order)
      expect(all("input[name='asset_ids[]']")).to all(not_be_disabled)
      expect(all("[data-uncategorized-kind-target~='row']").map { |row| row[:class] })
        .to all(exclude("opacity-40"))
      expect(available_role_values).to eq(%w[ background standing cutin panel bgm sound_effect other ])
    end
  end
end
