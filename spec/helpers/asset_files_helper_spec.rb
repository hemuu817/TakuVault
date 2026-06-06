require "rails_helper"

RSpec.describe AssetFilesHelper, type: :helper do
  describe "#asset_file_download_path" do
    it "returns a download blob path for an attached asset" do
      asset = create(:asset)

      expect(helper.asset_file_download_path(asset)).to include("/rails/active_storage/blobs/")
      expect(helper.asset_file_download_path(asset)).to include("disposition=attachment")
    end

    it "returns nil when the file is not attached" do
      asset = build_stubbed(:asset)
      allow(asset.file).to receive(:attached?).and_return(false)

      expect(helper.asset_file_download_path(asset)).to be_nil
    end
  end

  describe "#asset_file_thumbnail_src" do
    it "returns a blob path for an image asset" do
      asset = create(:asset)

      expect(helper.asset_file_thumbnail_src(asset)).to include("/rails/active_storage/blobs/")
    end

    it "returns the audio placeholder for an audio asset" do
      asset = build(:asset, original_filename: "sound.mp3", display_name: "sound.mp3")
      asset.file.detach
      asset.file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/valid.png")),
        filename: "sound.mp3",
        content_type: "audio/mpeg",
        identify: false
      )
      asset.save!

      expect(helper.asset_file_thumbnail_src(asset)).to include("audio-placeholder")
    end

    it "returns nil when the file is not attached" do
      asset = build_stubbed(:asset)
      allow(asset.file).to receive(:attached?).and_return(false)

      expect(helper.asset_file_thumbnail_src(asset)).to be_nil
    end
  end
end
