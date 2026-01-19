class CreateAssets < ActiveRecord::Migration[7.1]
  def change
    create_table :assets do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :display_name, null: false
      t.string :original_filename, null: false

      t.timestamps
    end
  end
end
