class ChangeGuidFormatInFeedEntries < ActiveRecord::Migration
    def up
        change_column :feed_entries, :guid, :text
    end

    def down
        change_column :feed_entries, :guid, :string
    end
end
