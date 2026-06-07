require "rails_helper"

RSpec.describe Assets::UploadValidator do
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

  it "許可された形式は通過する" do
    result = described_class.new(files: [ valid_file ]).call

    expect(result.ok?).to be(true)
    expect(result.total_bytes).to be > 0
  end

  it "files が nil の場合は拒否する" do
    result = described_class.new(files: nil).call

    expect(result.ok?).to be(false)
    expect(result.error).to eq(:no_files)
  end

  it "files が空配列の場合は拒否する" do
    result = described_class.new(files: []).call

    expect(result.ok?).to be(false)
    expect(result.error).to eq(:no_files)
  end

  it "1回の件数上限を超えると拒否する" do
    stub_const("Assets::UploadValidator::MAX_FILES_PER_UPLOAD", 1)
    second_file = Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/valid.png"),
      "image/png"
    )

    result = described_class.new(files: [ valid_file, second_file ]).call

    expect(result.ok?).to be(false)
    expect(result.error).to eq(:too_many_files)
  end

  it "アップロードファイル型でない要素が含まれる場合は拒否する" do
    result = described_class.new(files: [ "not-uploaded-file" ]).call

    expect(result.ok?).to be(false)
    expect(result.error).to eq(:invalid_file_param)
  end

  it "実体MIMEと拡張子が一致しない場合は拒否する" do
    result = described_class.new(files: [ fake_png ]).call

    expect(result.ok?).to be(false)
    expect(result.error).to eq(:invalid_content_type)
  end

  it "application/ogg と判定された .ogg は拒否する" do
    ogg_file = Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/valid.png"),
      "application/ogg",
      original_filename: "sound.ogg"
    )
    allow(Marcel::MimeType).to receive(:for).and_return("application/ogg")

    result = described_class.new(files: [ ogg_file ]).call

    expect(result.ok?).to be(false)
    expect(result.error).to eq(:invalid_content_type)
  end

  it "1ファイル上限を超えると拒否する" do
    stub_const("Assets::UploadValidator::MAX_FILE_BYTES", 1)

    result = described_class.new(files: [ valid_file ]).call

    expect(result.ok?).to be(false)
    expect(result.error).to eq(:file_too_large)
  end

  it "1回合計上限を超えると拒否する" do
    stub_const("Assets::UploadValidator::MAX_UPLOAD_TOTAL_BYTES", 1)

    result = described_class.new(files: [ valid_file ]).call

    expect(result.ok?).to be(false)
    expect(result.error).to eq(:total_bytes_over_limit)
  end
end
