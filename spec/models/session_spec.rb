require "rails_helper"

RSpec.describe Session, type: :model do
  describe "room_url バリデーション" do
    it "http URL は有効" do
      expect(build(:session, room_url: "http://example.com")).to be_valid
    end

    it "https URL は有効" do
      expect(build(:session, room_url: "https://example.com")).to be_valid
    end

    it "room_url が nil は有効" do
      expect(build(:session, room_url: nil)).to be_valid
    end

    it "room_url が空文字は有効" do
      expect(build(:session, room_url: "")).to be_valid
    end

    it "javascript: スキームは無効" do
      s = build(:session, room_url: "javascript:alert(1)")
      expect(s).not_to be_valid
      expect(s.errors[:room_url]).not_to be_empty
    end

    it "ftp: スキームは無効" do
      expect(build(:session, room_url: "ftp://example.com")).not_to be_valid
    end

    it "data: スキームは無効" do
      expect(build(:session, room_url: "data:text/html,<h1>hi</h1>")).not_to be_valid
    end

    it "スキームなし URL は無効" do
      expect(build(:session, room_url: "example.com")).not_to be_valid
    end
  end

  describe "room_url DB CHECK制約" do
    it "nil を保存できる" do
      expect { create(:session, room_url: nil) }.to change(Session, :count).by(1)
    end

    it "空文字を保存できる" do
      expect { create(:session, room_url: "") }.to change(Session, :count).by(1)
    end

    it "http URL を保存できる" do
      expect { create(:session, room_url: "http://example.com/room") }.to change(Session, :count).by(1)
    end

    it "https URL を保存できる" do
      expect { create(:session, room_url: "https://example.com/room") }.to change(Session, :count).by(1)
    end

    it "javascript: はバリデーションを迂回してもDBが拒否する" do
      session = build(:session, room_url: "javascript:alert(1)")

      expect { session.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "data: はバリデーションを迂回してもDBが拒否する" do
      session = build(:session, room_url: "data:text/html,<h1>hi</h1>")

      expect { session.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "ftp: はバリデーションを迂回してもDBが拒否する" do
      session = build(:session, room_url: "ftp://example.com/room")

      expect { session.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe "name バリデーション" do
    it "name が空は無効" do
      s = build(:session, name: "")
      expect(s).not_to be_valid
      expect(s.errors[:name]).not_to be_empty
    end
  end
end
