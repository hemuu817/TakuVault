module Assets
  class UploadValidator
    MAX_FILE_BYTES = 50_000_000
    MAX_USER_TOTAL_BYTES = 500_000_000
    MAX_FILES_PER_UPLOAD = 30
    MAX_UPLOAD_TOTAL_BYTES = 200_000_000

    ALLOWED_CONTENT_TYPES = %w[
      image/png
      image/jpeg
      image/webp
      audio/mpeg
      audio/mp3
      audio/wav
      audio/x-wav
    ].freeze

    ALLOWED_EXTENSIONS = %w[
      .png
      .jpg
      .jpeg
      .webp
      .mp3
      .wav
    ].freeze

    Result = Struct.new(:ok?, :error, :details, :total_bytes, keyword_init: true)

    def initialize(files:)
      @files = files
    end

    def call
      files = normalized_files
      return reject(:no_files) if files.empty?
      if files.size > MAX_FILES_PER_UPLOAD
        return reject(:too_many_files, count: files.size, max: MAX_FILES_PER_UPLOAD)
      end

      total_bytes = 0

      files.each do |file|
        unless uploaded_file_like?(file)
          return reject(:invalid_file_param, class_name: file.class.name)
        end

        total_bytes += file.size
        if file.size > MAX_FILE_BYTES
          return reject(:file_too_large, filename: file.original_filename, size: file.size)
        end
        if total_bytes > MAX_UPLOAD_TOTAL_BYTES
          return reject(:total_bytes_over_limit, total_bytes: total_bytes)
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

      Result.new(ok?: true, total_bytes: total_bytes)
    end

    private

    def normalized_files
      Array(@files).reject(&:blank?)
    end

    def uploaded_file_like?(file)
      file.respond_to?(:size) &&
        file.respond_to?(:original_filename) &&
        file.respond_to?(:tempfile)
    end

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
