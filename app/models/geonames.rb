class Geonames < ActiveRecord::Base
  attr_accessible :acode, :fclass, :geonameid, :latitude, :longitude, :name, :population
end
