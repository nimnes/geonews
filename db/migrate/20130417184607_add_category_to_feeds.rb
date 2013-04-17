class AddCategoryToFeeds < ActiveRecord::Migration
  def change
    add_column :feeds, :category, :integer
  end
end
