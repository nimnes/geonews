class AddPersonsToLearningCorpus < ActiveRecord::Migration
  def change
    add_column :learning_corpus, :persons, :text
  end
end
