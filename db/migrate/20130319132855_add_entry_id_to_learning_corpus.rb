class AddEntryIdToLearningCorpus < ActiveRecord::Migration
  def change
    add_column :learning_corpus, :entryid, :string
  end
end
