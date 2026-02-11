module Assets
  class BulkCreate
    class TotalCapacityExceeded < StandardError; end

    Result = Struct.new(:assets, :error, keyword_init: true) do
      def success?
        error.nil?
      end
    end

    def self.call(user:, files:)
      new(user: user, files: files).call
    end

    def initialize(user:, files:)
      @user = user
      @files = files
    end

    def call
      files = normalized_files
      validation = UploadValidator.new(files: files).call
      return Result.new(error: validation.error) unless validation.ok?

      assets = []
      Asset.transaction do
        User.lock.find(@user.id)
        current_total = current_total_bytes
        incoming_total = validation.total_bytes

        if current_total + incoming_total > UploadValidator::MAX_USER_TOTAL_BYTES
          log_rejection(:total_capacity_exceeded,
                        current_total: current_total,
                        incoming_total: incoming_total)
          raise TotalCapacityExceeded
        end

        files.each do |file|
          asset = Asset.new(
            user: @user,
            original_filename: file.original_filename,
            display_name: file.original_filename
          )
          asset.file.attach(file)
          asset.save!
          assets << asset
        end
      end

      Result.new(assets: assets)
    rescue TotalCapacityExceeded
      Result.new(error: :total_capacity_exceeded)
    rescue ActiveRecord::RecordInvalid => e
      log_rejection(:record_invalid, error: e.message)
      Result.new(error: :record_invalid)
    end

    private

    def normalized_files
      Array(@files).reject(&:blank?)
    end

    def current_total_bytes
      ActiveStorage::Attachment
        .joins(:blob)
        .where(record_type: "Asset")
        .joins("INNER JOIN assets ON assets.id = active_storage_attachments.record_id")
        .where(assets: { user_id: @user.id })
        .sum("active_storage_blobs.byte_size")
    end

    def log_rejection(reason, details = {})
      Rails.logger.info({ event: "asset_upload_rejected", reason: reason, **details })
    end
  end
end
