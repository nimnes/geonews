class AddEntryDateToLearningCorpus < ActiveRecord::Migration
  def change
    add_column :learning_corpus, :entrydate, :datetime
  end
end
