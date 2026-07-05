module Assets
  class KindClassifier
    def self.call(content_type)
      new(content_type).call
    end

    def initialize(content_type)
      @content_type = content_type.to_s
    end

    def call
      return :image if @content_type.start_with?("image/")
      return :audio if @content_type.start_with?("audio/")

      :other
    end
  end
end
