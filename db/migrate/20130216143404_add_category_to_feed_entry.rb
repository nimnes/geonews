class AddCategoryToFeedEntry < ActiveRecord::Migration
  def change
    add_column :feed_entries, :category, :string
  end
end
