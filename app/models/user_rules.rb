class UserRules < ActiveRecord::Base
  attr_accessible :referent, :rule, :toponym, :ruletype
end
