class Document
    attr_reader :id
    attr_reader :text
    attr_reader :tokens
    attr_reader :term_counts
    attr_reader :size

    def initialize(text, opts = {})
        @text        = text
        @id          = opts[:id] || object_id
        @tokens      = opts[:tokens]
        @term_counts = Hash.new 0
        process
    end

    def term_frequency(term)
        term_counts[term]
    end

    def terms
        term_counts.keys
    end

    private
    def process
        if tokens.present?
            tokens.each do |term|
                @term_counts[term] += 1
            end
        else
            text.split(',').each do |term|
                @term_counts[term] += 1
            end
        end

        @size = term_counts.values.reduce(:+)
    end
end