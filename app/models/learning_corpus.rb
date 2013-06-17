# encoding: utf-8
require 'benchmark'
require './lib/learning/collection'

class LearningCorpus < ActiveRecord::Base
    attr_accessible :context, :entryid, :referents, :toponym, :persons, :entrydate

    CORPUS_SIZE = 2000
    MIN_CORPUS_SIZE = 500

    @context_corpus = Collection.new
    @persons_corpus = Collection.new

    # create corpuses for news contexts and persons
    def self.create_corpus
        time = Benchmark.realtime do
            LearningCorpus.all.each do |lc|
                @context_corpus << Document.new(lc.context, {:id => lc.entryid})
                @persons_corpus << Document.new(lc.persons, {:id => lc.entryid})
            end
        end

        puts "[LEARNING] terms corpuses created in #{'%.3f' % time} seconds"
    end

    def self.add_document_terms(c_terms, p_terms, entryid)
        @context_corpus << Document.new('', {:id => entryid, :tokens => c_terms})
        @persons_corpus << Document.new('', {:id => entryid, :tokens => p_terms})
    end

    def self.add_entry(context, toponym, referents, entry_persons, entry_id)
        context_str = context.join(',')
        persons_str = entry_persons.uniq.join(',')

        self.add_document_terms(context, entry_persons, entry_id.to_s)

        # delete first record (oldest) and add new one to the end
        # it is needed for keeping constant size of Learning corpus
        if @context_corpus.documents.size >= CORPUS_SIZE
            LearningCorpus.first.delete
        end

        LearningCorpus.create!(
            :context         => context_str,
            :toponym         => toponym,
            :referents       => referents,
            :persons         => persons_str,
            :entryid         => entry_id,
            :entrydate       => FeedEntry.where('guid = ?', entry_id.to_s).first.published_at
        )
    end

    def self.consistent?
        @context_corpus.documents.size >= MIN_CORPUS_SIZE
    end

    def self.has_entry?(entry_id)
        return LearningCorpus.where('entryid = ?', entry_id.to_s).present?
    end

    def self.get_similar_entries(text)
        @context_corpus.similar_documents(text)
    end

    def self.get_entries_with_persons(persons_arr)
        similar_entries = @persons_corpus.similar_documents(persons_arr)

        possible_locations = {}

        # save only persons who meet in few feed entries
        # and return only most popular location
        if similar_entries.count > 1
            similar_entries.each do |entryid, score|
                entry = LearningCorpus.where('entryid = ?', entryid.to_s).first
                if entry.present?
                    possible_locations[entry.referents.split(';').first] = entry.toponym
                end
            end
        end

        possible_locations
    end
end
