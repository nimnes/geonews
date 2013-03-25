class CreateGeonames < ActiveRecord::Migration
  def change
    create_table :geonames do |t|
      t.string :geonameid
      t.text :name
      t.float :latitude
      t.float :longitude
      t.string :fclass
      t.string :acode
      t.integer :population

      t.timestamps
    end
  end
end
