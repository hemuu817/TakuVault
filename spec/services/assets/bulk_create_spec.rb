require "rails_helper"

RSpec.describe Assets::BulkCreate do
  let(:user) { create(:user) }
  let(:valid_file) do
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/valid.png"),
      "image/png"
    )
  end
  let(:fake_png) do
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/fake.png"),
      "image/png"
    )
  end

  it "全ファイルが有効ならAssetを一括作成する" do
    expect do
      result = described_class.call(user: user, files: [ valid_file ])
      expect(result).to be_success
    end.to change(Asset, :count).by(1)
      .and change(ActiveStorage::Attachment, :count).by(1)

    asset = Asset.last
    expect(asset.display_name).to eq("valid.png")
    expect(asset.original_filename).to eq("valid.png")
  end

  it "形式不正なら何も作成されない" do
    counts = {
      assets: Asset.count,
      attachments: ActiveStorage::Attachment.count,
      blobs: ActiveStorage::Blob.count
    }

    result = described_class.call(user: user, files: [ fake_png ])

    expect(result).not_to be_success
    expect(result.error).to eq(:invalid_content_type)
    expect(Asset.count).to eq(counts[:assets])
    expect(ActiveStorage::Attachment.count).to eq(counts[:attachments])
    expect(ActiveStorage::Blob.count).to eq(counts[:blobs])
  end

  it "アップロードファイル型でない要素なら何も作成されない" do
    counts = {
      assets: Asset.count,
      attachments: ActiveStorage::Attachment.count,
      blobs: ActiveStorage::Blob.count
    }

    result = described_class.call(user: user, files: [ "not-uploaded-file" ])

    expect(result).not_to be_success
    expect(result.error).to eq(:invalid_file_param)
    expect(Asset.count).to eq(counts[:assets])
    expect(ActiveStorage::Attachment.count).to eq(counts[:attachments])
    expect(ActiveStorage::Blob.count).to eq(counts[:blobs])
  end

  it "混在で1件でも不正なら何も作成されない" do
    counts = {
      assets: Asset.count,
      attachments: ActiveStorage::Attachment.count,
      blobs: ActiveStorage::Blob.count
    }

    result = described_class.call(user: user, files: [ valid_file, fake_png ])

    expect(result).not_to be_success
    expect(result.error).to eq(:invalid_content_type)
    expect(Asset.count).to eq(counts[:assets])
    expect(ActiveStorage::Attachment.count).to eq(counts[:attachments])
    expect(ActiveStorage::Blob.count).to eq(counts[:blobs])
  end

  it "総容量超過なら何も作成されない" do
    asset = create(:asset, user: user, original_filename: "existing.png", display_name: "existing.png")
    existing_size = asset.file.blob.byte_size
    stub_const("Assets::UploadValidator::MAX_USER_TOTAL_BYTES", existing_size)

    expect do
      result = described_class.call(user: user, files: [ valid_file ])
      expect(result).not_to be_success
      expect(result.error).to eq(:total_capacity_exceeded)
    end.not_to change(Asset, :count)
  end
end
