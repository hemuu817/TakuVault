module Assets
  class UploadValidator
    MAX_FILE_BYTES = 50_000_000
    MAX_TOTAL_BYTES = 500_000_000
    MAX_FILES_PER_UPLOAD = 30
    MAX_TOTAL_BYTES_PER_UPLOAD = 200_000_000

    ALLOWED_CONTENT_TYPES = %w[
      image/png
      image/jpeg
      image/webp
      audio/mpeg
      audio/mp3
      audio/wav
      audio/x-wav
      audio/ogg
      application/ogg
    ].freeze

    ALLOWED_EXTENSIONS = %w[
      .png
      .jpg
      .jpeg
      .webp
      .mp3
      .wav
      .ogg
    ].freeze

    Result = Struct.new(:ok?, :error, :details, :total_bytes, keyword_init: true)

    def initialize(files:)
      @files = files
    end

    def call
      total_bytes = 0

      @files.each do |file|
        total_bytes += file.size
        if file.size > MAX_FILE_BYTES
          return reject(:file_too_large, filename: file.original_filename, size: file.size)
        end

        detected_mime = detect_mime(file)
        extension = file_extension(file.original_filename)
        unless ALLOWED_CONTENT_TYPES.include?(detected_mime) && ALLOWED_EXTENSIONS.include?(extension)
          return reject(:invalid_content_type,
                        filename: file.original_filename,
                        detected_mime: detected_mime,
                        extension: extension)
        end
      end

      if total_bytes > MAX_TOTAL_BYTES_PER_UPLOAD
        return reject(:total_bytes_over_limit, total_bytes: total_bytes)
      end

      Result.new(ok?: true, total_bytes: total_bytes)
    end

    private

    def detect_mime(file)
      Marcel::MimeType.for(file.tempfile)
    end

    def file_extension(filename)
      File.extname(filename.to_s).downcase
    end

    def reject(reason, details = {})
      Rails.logger.info({ event: "asset_upload_rejected", reason: reason, **details })
      Result.new(ok?: false, error: reason, details: details)
    end
  end
end
