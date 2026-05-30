class AddRoleCheckToUsages < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :usages,
                         "role IN (0, 1, 2, 3)",
                         name: "usages_role_allowed_values"
  end
end
