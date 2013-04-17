class AddFeedCategoryToFeedEntry < ActiveRecord::Migration
  def change
    add_column :feed_entries, :feedcategory, :integer
  end
end
