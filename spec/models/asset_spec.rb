require "rails_helper"

RSpec.describe Asset, type: :model do
  let(:valid_file_path) { Rails.root.join("spec/fixtures/files/valid.png") }
  let(:user) { create(:user) }

  def attach_file(asset, filename:, content_type:)
    asset.file.attach(
      io: File.open(valid_file_path),
      filename: filename,
      content_type: content_type,
      identify: false
    )
  end

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

  it "添付がない場合でも kind callback は例外化しない" do
    asset = build(:asset, original_filename: "sample.png", display_name: "sample.png")
    asset.file.detach

    expect { asset.valid? }.not_to raise_error
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

  it "kind enum は other/image/audio の固定値のみを持つ" do
    expect(described_class.kinds).to eq({
      "other" => 0,
      "image" => 1,
      "audio" => 2
    })
    expect(described_class.kinds).not_to have_key("video")
  end

  it "image/png の添付は image に分類される" do
    asset = described_class.new(user: user, original_filename: "sample.png", display_name: "sample.png")
    attach_file(asset, filename: "sample.png", content_type: "image/png")

    asset.save!

    expect(asset).to be_image
  end

  it "image/jpeg の添付は image に分類される" do
    asset = described_class.new(user: user, original_filename: "sample.jpg", display_name: "sample.jpg")
    attach_file(asset, filename: "sample.jpg", content_type: "image/jpeg")

    asset.save!

    expect(asset).to be_image
  end

  it "audio/mpeg の添付は audio に分類される" do
    asset = described_class.new(user: user, original_filename: "sound.mp3", display_name: "sound.mp3")
    attach_file(asset, filename: "sound.mp3", content_type: "audio/mpeg")

    asset.save!

    expect(asset).to be_audio
  end

  it "audio/wav の添付は audio に分類される" do
    asset = described_class.new(user: user, original_filename: "sound.wav", display_name: "sound.wav")
    attach_file(asset, filename: "sound.wav", content_type: "audio/wav")

    asset.save!

    expect(asset).to be_audio
  end

  it "作成時は内部的に指定された kind より添付Blob由来の分類を優先する" do
    asset = described_class.new(
      user: user,
      original_filename: "sample.png",
      display_name: "sample.png",
      kind: :audio
    )
    attach_file(asset, filename: "sample.png", content_type: "image/png")

    asset.save!

    expect(asset).to be_image
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
