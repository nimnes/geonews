class CreateWorldCities < ActiveRecord::Migration
  def change
    create_table :world_cities do |t|
      t.string :geonameid
      t.text :name
      t.float :latitude
      t.float :longitude
      t.integer :population

      t.timestamps
    end
  end
end
