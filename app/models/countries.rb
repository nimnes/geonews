class Countries < ActiveRecord::Base
  attr_accessible :capital, :code, :latitude, :longitude, :name
end
