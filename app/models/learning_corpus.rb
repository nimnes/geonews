# encoding: utf-8
require 'benchmark'

class LearningCorpus < ActiveRecord::Base
    attr_accessible :context, :entryid, :referents, :toponym, :persons, :entrydate

    CORPUS_SIZE = 2000
    MIN_CORPUS_SIZE = 500
    MIN_SIMILARITY = 0.55

    @context_terms = Containers::Trie.new
    @persons_terms = Containers::Trie.new
    @docs_count = 0

    # count documents frequency of terms for cosine similarity with tf-idf
    def self.count_df
        time = Benchmark.realtime do
            @docs_count = LearningCorpus.count

            LearningCorpus.all.each do |lc|
                c_terms = lc.context.split(',').uniq
                p_terms = lc.persons.split(',').uniq

                c_terms.each do |term|
                    add_context_term(term)
                end

                p_terms.each do |term|
                    add_persons_term(term)
                end
            end
        end

        puts "[LEARNING] document frequencies were counted in #{'%.3f' % time} seconds"
    end

    def self.add_context_term(term)
        if @context_terms.has_key?(term)
            @context_terms[term] += 1
        else
            @context_terms[term] = 1
        end
    end

    def self.add_persons_term(term)
        if @persons_terms.has_key?(term)
            @persons_terms[term] += 1
        else
            @persons_terms[term] = 1
        end
    end

    def self.add_document_terms(c_terms, p_terms)
        c_terms.uniq.each do |term|
            add_context_term(term)
        end

        p_terms.uniq.each do |term|
            add_persons_term(term)
        end
    end

    def self.context_idf(term)
        if @context_terms.has_key?(term)
            return Math.log10(@docs_count / @context_terms.get(term))
        else
            return 1
        end
    end

    def self.persons_idf(term)
        if @persons_terms.has_key?(term)
            return Math.log10(@docs_count / @persons_terms.get(term))
        else
            return 1
        end
    end

    def self.add_entry(context, toponym, referents, entry_persons, entry_id)
        context_str = ''
        persons_str = ''

        context.each do |w|
            context_str += w + ','
        end

        unless context_str.blank?
            context_str = context_str[0...-1]
        end

        entry_persons.each do |p|
            persons_str += p + ','
        end

        unless persons_str.blank?
            persons_str = persons_str[0...-1]
        end

        self.add_document_terms(context, entry_persons)

        # delete first record (oldest) and add new one to the end
        # it is needed for keeping constant size of Learning corpus
        if @docs_count >= CORPUS_SIZE
            LearningCorpus.first.delete
        else
            @docs_count += 1
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
        @docs_count >= MIN_CORPUS_SIZE
    end

    def self.get_similar_entries(text)
        similar_entries = []

        LearningCorpus.all.each do |item|
            vectors = self.vectorize_context(item.context.split(','), text)

            cos_similarity = self.cosine_similarity(vectors.first, vectors.last)
            if cos_similarity >= MIN_SIMILARITY
                similar_entries << [item, cos_similarity]
            end
        end

        similar_entries.sort_by {|x,y| y}
    end

    def self.get_entries_with_persons(persons_arr)
        similar_entries = []

        LearningCorpus.all.each do |item|
            # check only new entries, because location for this persons can change
            if item.persons.blank? or item.entrydate < 12.hours.ago
                next
            end

            vectors = self.vectorize_persons(item.persons.split(','), persons_arr)

            cos_similarity = self.cosine_similarity(vectors.first, vectors.last)

            if cos_similarity >= MIN_SIMILARITY
                similar_entries << [item, cos_similarity]
            end
        end

        possible_locations = {}

        # save only persons who meet in few feed entries
        # and return only most popular location
        if similar_entries.count > 1
            similar_entries.each do |entry, score|
                possible_locations[entry.referents.split(';').first] = entry.toponym
            end
        end

        return possible_locations
    end

    # create vectors for two texts
    # it will be used later for cosine similarity
    def self.vectorize_context(a, b)
        tokens = []

        a.each do |t|
            unless tokens.include?(t)
                tokens << t
            end
        end

        b.each do |t|
            unless tokens.include?(t)
                tokens << t
            end
        end

        a_vec = Array.new(tokens.count, 0)
        b_vec = Array.new(tokens.count, 0)

        tokens = tokens.sort_by {|x| x}

        tokens.each_with_index do |t, index|
            if a.include?(t)
                a_vec[index] += a.count(t) * context_idf(t)
            end

            if b.include?(t)
                b_vec[index] += b.count(t) * context_idf(t)
            end
        end

        return [a_vec, b_vec]
    end

    def self.vectorize_persons(a, b)
        tokens = []

        a.each do |t|
            unless tokens.include?(t)
                tokens << t
            end
        end

        b.each do |t|
            unless tokens.include?(t)
                tokens << t
            end
        end

        a_vec = Array.new(tokens.count, 0)
        b_vec = Array.new(tokens.count, 0)

        tokens = tokens.sort_by {|x| x}

        tokens.each_with_index do |t, index|
            if a.include?(t)
                a_vec[index] += a.count(t) * persons_idf(t)
            end

            if b.include?(t)
                b_vec[index] += b.count(t) * persons_idf(t)
            end
        end

        return [a_vec, b_vec]
    end

    def self.has_entry?(entry_id)
        return LearningCorpus.where('entryid = ?', entry_id.to_s).present?
    end

    def self.dot_product(a, b)
        products = a.zip(b).map{|x, y| x * y}
        products.inject(0) {|s,p| s + p}
    end

    def self.magnitude(point)
        squares = point.map{|x| x**2}
        Math.sqrt(squares.inject(0) {|s, c| s + c})
    end

    # Returns the cosine of the angle between the vectors
    # associated with 2 points
    #
    # Params:
    #  - a, b: list of coordinates (float or integer)
    def self.cosine_similarity(a, b)
        dot_product(a, b) / (magnitude(a) * magnitude(b))
    end

end
