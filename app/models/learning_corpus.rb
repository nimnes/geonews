class LearningCorpus < ActiveRecord::Base
    attr_accessible :context, :entryid, :referents, :toponym

    CORPUS_SIZE = 2000
    MIN_CORPUS_SIZE = 500
    MIN_SIMILARITY = 0.55

    def self.add_entry(context, toponym, referents, entry_id)
        context_str = ''

        context.each do |w|
            context_str += w + ','
        end

        unless context_str.blank?
            context_str = context_str[0...-1]
        end

        # delete first record (oldest) and add new one to the end
        # it is needed for keeping constant size of Learning corpus
        if LearningCorpus.count > CORPUS_SIZE
            LearningCorpus.first.delete
        end

        LearningCorpus.create!(
            :context         => context_str,
            :toponym         => toponym,
            :referents       => referents,
            :entryid         => entry_id,
        )
    end

    def self.consistent?
        LearningCorpus.count >= MIN_CORPUS_SIZE
    end

    def self.get_similar_entries(text)
        similar_entries = []

        LearningCorpus.all.each do |item|
            vectors = self.vectorize(item.context.split(','), text)

            cos_similarity = self.cosine_similarity(vectors.first, vectors.last)
            if cos_similarity >= MIN_SIMILARITY
                similar_entries << [item, cos_similarity]
            end
        end

        similar_entries.sort_by {|x,y| y}
    end

    # create vectors for two texts
    # it will be used later for cosine similarity
    def self.vectorize(a, b)
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
                a_vec[index] += a.count(t)
            end

            if b.include?(t)
                b_vec[index] += b.count(t)
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
