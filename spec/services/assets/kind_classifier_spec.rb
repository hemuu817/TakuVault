require "rails_helper"

RSpec.describe Assets::KindClassifier do
  describe ".call" do
    {
      "image/png" => :image,
      "image/jpeg" => :image,
      "image/webp" => :image,
      "audio/mpeg" => :audio,
      "audio/mp3" => :audio,
      "audio/wav" => :audio,
      "audio/x-wav" => :audio,
      "application/octet-stream" => :other,
      "text/plain" => :other,
      nil => :other,
      "" => :other
    }.each do |content_type, kind|
      it "classifies #{content_type.inspect} as #{kind}" do
        expect(described_class.call(content_type)).to eq(kind)
      end
    end
  end
end
