require "rails_helper"

RSpec.describe Asset, type: :model do
  let(:valid_file_path) { Rails.root.join("spec/fixtures/files/valid.png") }

  it "display_name が空なら original_filename を採用する" do
    asset = build(:asset, original_filename: "sample.png", display_name: "")

    asset.valid?

    expect(asset.display_name).to eq("sample.png")
  end

  it "添付がない場合は無効" do
    asset = build(:asset, original_filename: "sample.png", display_name: "sample.png")
    asset.file.detach

    expect(asset).not_to be_valid
    expect(asset.errors[:file]).not_to be_empty
  end

  it "許可外の拡張子は無効" do
    asset = build(:asset, original_filename: "sample.txt", display_name: "sample.txt")
    asset.file.attach(
      io: File.open(valid_file_path),
      filename: "sample.txt",
      content_type: "image/png"
    )

    expect(asset).not_to be_valid
    expect(asset.errors[:file]).not_to be_empty
  end

  it "application/ogg の添付は無効" do
    asset = build(:asset, original_filename: "sound.ogg", display_name: "sound.ogg")
    asset.file.attach(
      io: File.open(valid_file_path),
      filename: "sound.ogg",
      content_type: "application/ogg",
      identify: false
    )

    expect(asset).not_to be_valid
    expect(asset.errors[:file]).not_to be_empty
  end

  it "サイズ上限を超えると無効" do
    stub_const("Assets::UploadValidator::MAX_FILE_BYTES", 1)

    asset = build(:asset, original_filename: "sample.png", display_name: "sample.png")
    asset.file.attach(
      io: File.open(valid_file_path),
      filename: "sample.png",
      content_type: "image/png"
    )

    expect(asset).not_to be_valid
    expect(asset.errors[:file]).not_to be_empty
  end
end
