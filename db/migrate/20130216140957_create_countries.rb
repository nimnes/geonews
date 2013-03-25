class CreateCountries < ActiveRecord::Migration
  def change
    create_table :countries do |t|
      t.string :code
      t.text :name
      t.text :capital
      t.float :latitude
      t.float :longitude

      t.timestamps
    end
  end
end
