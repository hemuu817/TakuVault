class CreateUsages < ActiveRecord::Migration[7.2]
  def change
    create_table :usages do |t|
      t.references :asset, null: false
      t.bigint :session_id, null: false
      t.bigint :scene_id, null: false
      t.integer :role, null: false

      t.timestamps
    end

    add_index :usages,
              [ :asset_id, :session_id, :scene_id, :role ],
              unique: true,
              name: "index_usages_on_asset_id_and_session_id_and_scene_id_and_role"
    add_index :usages, [ :session_id, :scene_id ]

    add_foreign_key :usages, :assets, on_delete: :cascade, name: "fk_usages_asset"
    add_foreign_key :usages,
                    :scenes,
                    column: [ :session_id, :scene_id ],
                    primary_key: [ :session_id, :id ],
                    on_delete: :cascade,
                    name: "fk_usages_session_scene"
  end
end
