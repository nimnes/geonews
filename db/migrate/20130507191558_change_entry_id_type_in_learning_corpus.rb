class ChangeEntryIdTypeInLearningCorpus < ActiveRecord::Migration
    def up
        change_column :learning_corpus, :entryid, :text
    end

    def down
        change_column :learning_corpus, :entryid, :string
    end
end
