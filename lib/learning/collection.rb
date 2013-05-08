require './lib/learning/document'
require 'matrix'
require 'parallel'

class Collection
    attr_reader :documents
    attr_reader :term_counts
    attr_reader :document_counts

    MIN_SIMILARITY = 0.58

    def initialize
        @documents = []
        @term_counts = Hash.new 0
        @document_counts = Hash.new 0
        @freq_matrix = nil
    end

    def terms
        term_counts.keys
    end

    def <<(document)
        document.term_counts.each do |term,count|
            @term_counts[term] += count
            @document_counts[term] += 1
        end

        @documents << document
    end

    def idf(term)
        if @document_counts[term] == 0
            return 0
        end

        Math.log10(documents.size / document_counts[term])
    end

    def tf(document, term)
        document.term_frequency(term)
    end

    def similar_documents(tokens)
        document = Document.new('', {:tokens => tokens})

        results = Parallel.map(documents, :in_threads => 3) do |doc|
            vectors = create_vectors(document, doc)
            cos_similarity = cosine_similarity(vectors[0], vectors[1])

            if cos_similarity >= MIN_SIMILARITY
                [doc.id, cos_similarity]
            end
        end

        results.compact.sort_by {|x,y| y}
    end

    def create_vectors(doc1, doc2)
        tokens = doc1.terms + doc2.terms
        tokens = tokens.sort_by {|x| x}
        tokens = tokens.uniq

        d1_vec = Array.new(tokens.count, 0)
        d2_vec = Array.new(tokens.count, 0)

        tokens.each_with_index do |t, index|
            d1_vec[index] = doc1.term_frequency(t) * idf(t)
            d2_vec[index] = doc2.term_frequency(t) * idf(t)
        end

        [d1_vec, d2_vec]
    end

    # Returns the cosine of the angle between the vectors
    # associated with 2 points
    #
    # Params:
    #  - a, b: list of coordinates (float or integer)
    def cosine_similarity(a, b)
        dot_product(a, b) / (magnitude(a) * magnitude(b))
    end

    def dot_product(a, b)
        products = a.zip(b).map{|x, y| x * y}
        products.inject(0) {|s,p| s + p}
    end

    def magnitude(point)
        squares = point.map{|x| x**2}
        Math.sqrt(squares.inject(0) {|s, c| s + c})
    end
end