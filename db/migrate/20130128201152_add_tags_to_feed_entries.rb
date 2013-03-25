class AddTagsToFeedEntries < ActiveRecord::Migration
  def change
    add_column :feed_entries, :tags, :string
  end
end
