class AddCountryCodeToWorldCities < ActiveRecord::Migration
  def change
    add_column :world_cities, :countrycode, :string
  end
end
