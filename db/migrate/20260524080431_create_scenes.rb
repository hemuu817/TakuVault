class CreateScenes < ActiveRecord::Migration[7.2]
  def change
    create_table :scenes do |t|
      t.references :session, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :scenes, [ :session_id, :position ], unique: true
    add_index :scenes, [ :session_id, :id ],       unique: true
  end
end
