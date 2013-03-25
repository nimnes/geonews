class DropGeonamesTable < ActiveRecord::Migration
  def up
      drop_table :geonames
  end

  def down
  end
end
