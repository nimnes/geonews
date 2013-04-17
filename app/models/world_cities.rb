class WorldCities < ActiveRecord::Base
  attr_accessible :geonameid, :latitude, :longitude, :name, :population, :countrycode
end
