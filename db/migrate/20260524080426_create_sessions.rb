class CreateSessions < ActiveRecord::Migration[7.2]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :room_url

      t.timestamps
    end

    add_check_constraint :sessions,
                         "room_url IS NULL OR room_url = '' OR room_url ~* '^https?://'",
                         name: "sessions_room_url_http_https_only"
  end
end
