class LearningCorpus < ActiveRecord::Base
  attr_accessible :context, :entryid, :referents, :toponym
end
