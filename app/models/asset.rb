class Asset < ApplicationRecord
  belongs_to :user
  has_one_attached :file

  attr_readonly :original_filename

  validates :display_name, presence: true
  validates :original_filename, presence: true
  validate :file_presence
  validate :file_size_within_limit, if: -> { file.attached? }
  validate :file_content_type_and_extension, if: -> { file.attached? }

  before_validation :set_display_name, if: -> { display_name.blank? && original_filename.present? }

  private

  def set_display_name
    self.display_name = original_filename
  end

  def file_presence
    errors.add(:file, :blank) unless file.attached?
  end

  def file_size_within_limit
    return if file.blob.byte_size <= Assets::UploadValidator::MAX_FILE_BYTES

    errors.add(:file, :too_large)
  end

  def file_content_type_and_extension
    content_type = file.blob.content_type
    extension = File.extname(original_filename.to_s).downcase
    allowed = Assets::UploadValidator::ALLOWED_CONTENT_TYPES.include?(content_type) &&
      Assets::UploadValidator::ALLOWED_EXTENSIONS.include?(extension)

    errors.add(:file, :invalid) unless allowed
  end
end
