class CreateUserRules < ActiveRecord::Migration
  def change
    create_table :user_rules do |t|
      t.string :rule
      t.string :toponym
      t.string :referent

      t.timestamps
    end
  end
end
