require "rails_helper"

RSpec.describe Scene, type: :model do
  let(:session_record) { create(:session) }

  describe "default_scene" do
    it "is created with each session at position 1" do
      default_scene = session_record.scenes.find_by(position: 1)

      expect(default_scene).to be_present
      expect(default_scene.name).to eq("scene1")
    end

    it "cannot be destroyed" do
      default_scene = session_record.scenes.find_by!(position: 1)

      expect(default_scene.destroy).to be(false)
      expect(default_scene.errors[:base]).not_to be_empty
      expect(default_scene.reload).to be_persisted
    end

    it "cannot move away from position 1" do
      default_scene = session_record.scenes.find_by!(position: 1)
      default_scene.position = 2

      expect(default_scene).not_to be_valid
      expect(default_scene.errors[:position]).not_to be_empty
    end

    it "allows name changes" do
      default_scene = session_record.scenes.find_by!(position: 1)

      expect(default_scene.update(name: "導入")).to be(true)
      expect(default_scene.reload.name).to eq("導入")
      expect(default_scene.position).to eq(1)
    end
  end

  describe ".create_with_next_position!" do
    it "assigns positions from max + 1" do
      first = described_class.create_with_next_position!(
        session: session_record,
        attributes: { name: "追加1" }
      )
      second = described_class.create_with_next_position!(
        session: session_record,
        attributes: { name: "追加2" }
      )

      expect(first.position).to eq(2)
      expect(second.position).to eq(3)
    end

    it "assigns a name from the saved position when name is blank" do
      first = described_class.create_with_next_position!(
        session: session_record,
        attributes: { name: "" }
      )
      second = described_class.create_with_next_position!(
        session: session_record,
        attributes: { name: "" }
      )

      expect(first.name).to eq("scene2")
      expect(second.name).to eq("scene3")
    end
  end

  describe "DB constraints" do
    it "rejects duplicate positions in the same session" do
      create(:scene, session: session_record, position: 2)
      duplicate = build(:scene, session: session_record, position: 2)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
