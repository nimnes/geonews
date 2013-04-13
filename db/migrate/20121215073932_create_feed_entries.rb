class CreateFeedEntries < ActiveRecord::Migration
  def change
    create_table :feed_entries do |t|
      t.string :name
      t.text :summary
      t.string :url
      t.datetime :published_at
      t.string :guid
      t.string :location
      t.string :tags
      t.string :category
      t.string :source

      t.timestamps
    end
  end
end
