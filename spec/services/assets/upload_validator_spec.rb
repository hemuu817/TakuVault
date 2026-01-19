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

  it "実体MIMEと拡張子が一致しない場合は拒否する" do
    result = described_class.new(files: [ fake_png ]).call

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
    stub_const("Assets::UploadValidator::MAX_TOTAL_BYTES_PER_UPLOAD", 1)

    result = described_class.new(files: [ valid_file ]).call

    expect(result.ok?).to be(false)
    expect(result.error).to eq(:total_bytes_over_limit)
  end
end
