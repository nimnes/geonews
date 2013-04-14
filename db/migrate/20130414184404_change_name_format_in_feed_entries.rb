class ChangeNameFormatInFeedEntries < ActiveRecord::Migration
  def up
      change_column :feed_entries, :name, :text
  end

  def down
      change_column :feed_entries, :name, :string
  end
end
