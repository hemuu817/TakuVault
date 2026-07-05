class AddKindToAssets < ActiveRecord::Migration[8.1]
  def change
    add_column :assets, :kind, :integer, null: false, default: 0
    add_check_constraint :assets,
                         "kind IN (0, 1, 2)",
                         name: "assets_kind_allowed_values"
  end
end
