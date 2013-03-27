class CreateLearningCorpus < ActiveRecord::Migration
  def change
    create_table :learning_corpus do |t|
      t.string :toponym
      t.text :context
      t.text :referents
      t.string :entryid

      t.timestamps
    end
  end
end
