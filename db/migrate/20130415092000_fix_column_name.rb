class FixColumnName < ActiveRecord::Migration
    def self.up
        rename_column :user_rules, :type, :ruletype
    end

    def self.down
        rename_column :user_rules, :ruletype, :type
    end
end
