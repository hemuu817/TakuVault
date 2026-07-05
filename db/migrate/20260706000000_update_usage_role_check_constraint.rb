class UpdateUsageRoleCheckConstraint < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :usages, name: :usages_role_allowed_values
    add_check_constraint :usages,
                         "role IN (0, 1, 2, 3, 4, 5, 6)",
                         name: :usages_role_allowed_values
  end

  def down
    if select_value("SELECT COUNT(*) FROM usages WHERE role IN (4, 5, 6)").to_i.positive?
      raise ActiveRecord::IrreversibleMigration,
            "Cannot restore usages_role_allowed_values to 0..3 while usages with roles 4..6 exist"
    end

    remove_check_constraint :usages, name: :usages_role_allowed_values
    add_check_constraint :usages,
                         "role IN (0, 1, 2, 3)",
                         name: :usages_role_allowed_values
  end
end
