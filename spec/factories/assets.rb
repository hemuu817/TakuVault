FactoryBot.define do
  factory :asset do
    association :user
    original_filename { "valid.png" }
    display_name { original_filename }

    after(:build) do |asset|
      file_path = Rails.root.join("spec/fixtures/files/valid.png")
      asset.file.attach(
        io: File.open(file_path),
        filename: asset.original_filename,
        content_type: "image/png"
      )
    end
  end
end
