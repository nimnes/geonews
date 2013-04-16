class AddTypeToUserRules < ActiveRecord::Migration
  def change
    add_column :user_rules, :type, :string
  end
end
