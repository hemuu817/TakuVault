require "rails_helper"

RSpec.describe Asset, type: :model do
  let(:valid_file_path) { Rails.root.join("spec/fixtures/files/valid.png") }
  let(:user) { create(:user) }

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

  it "audio/ogg の添付は無効" do
    asset = build(:asset, original_filename: "sound.ogg", display_name: "sound.ogg")
    asset.file.attach(
      io: File.open(valid_file_path),
      filename: "sound.ogg",
      content_type: "audio/ogg",
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

  it "DB default は other である" do
    kind_column = described_class.columns.find { |column| column.name == "kind" }

    expect(kind_column.default).to eq(0)
    expect(kind_column.null).to be(false)
  end

  it "DB制約で kind NULL は拒否される" do
    now = Time.current

    expect do
      described_class.insert_all!([
        {
          user_id: user.id,
          display_name: "null-kind.png",
          original_filename: "null-kind.png",
          kind: nil,
          created_at: now,
          updated_at: now
        }
      ])
    end.to raise_error(ActiveRecord::NotNullViolation)
  end

  it "DB制約で未定義の kind は拒否される" do
    now = Time.current

    expect do
      described_class.insert_all!([
        {
          user_id: user.id,
          display_name: "video-kind.png",
          original_filename: "video-kind.png",
          kind: 3,
          created_at: now,
          updated_at: now
        }
      ])
    end.to raise_error(ActiveRecord::StatementInvalid)
  end
end
