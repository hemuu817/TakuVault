module AssetFilesHelper
  AUDIO_PLACEHOLDER_IMAGE = "audio-placeholder.svg"

  def asset_file_download_path(asset)
    return unless asset.file.attached?

    rails_blob_path(asset.file, disposition: "attachment")
  end

  def asset_file_thumbnail_src(asset)
    return unless asset.file.attached?

    if asset_file_audio?(asset)
      image_path(AUDIO_PLACEHOLDER_IMAGE)
    elsif asset_file_image?(asset)
      rails_blob_path(asset.file)
    end
  end

  def asset_file_audio?(asset)
    asset.file.attached? && asset.file.blob.content_type.to_s.start_with?("audio/")
  end

  def asset_file_image?(asset)
    asset.file.attached? && asset.file.blob.content_type.to_s.start_with?("image/")
  end
end
