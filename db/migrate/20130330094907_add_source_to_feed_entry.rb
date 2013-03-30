class AddSourceToFeedEntry < ActiveRecord::Migration
  def change
    add_column :feed_entries, :source, :string
  end
end
