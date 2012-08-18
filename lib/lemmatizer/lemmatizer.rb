# encoding: utf-8
require "./lib/lemmatizer/morph"

class Lemmatizer
    Location = Struct.new(:latitude, :longitude)

    @@morph
    @@general_reductions = ["т.е.", "см.", "т.к.", "т.н.", "напр.", "т.г.", "т.о."]
    @@geo_reductions = { 
        "г."    => "город", 
        "ул."   => "улица",
        "с."    => "село",
        "пр."   => "проспект",
        "пл."   => "площадь",
        "пос."  => "поселок",
        "м."    => "метро",
        "респ." => "республика",
        "обл."  => "область"
    }

    def initialize
        @@morph = Morph.new()
        @@morph.load_dictionary("./dicts/morphs.mrd", "./dicts/rgramtab.tab")
    end

    def define_location(text)
        sentences = parse_sentences(text)
        normalized_text = []

        sentences.each do |s|
            words = parse_words(s)

            # define normal forms for all words in sentence
            # format is array of hashes { "word" => word, "normal_form" => normal_form }
            normal_sentence = @@morph.normalize_words(words)

            normalized_text << normal_sentence
        end

        return normalized_text
    end

    def parse_sentences(text)
        text = text.strip

        # remove all reductions from sentences, beacause it isn't influence on semantic meaning 
        # and ease parsing text on sentences
        @@general_reductions.each do |gd|
            text = text.gsub(gd, "")
        end

        # replace geo reductions with full name in first form
        @@geo_reductions.each do |key, value|
            text = text.gsub(key, value)
        end

        sentences = text.split(/(?![а-яА-Я])(?<=\.|\!|\?)(?!\")\s+(?=\"?[А-Я])/)
        return sentences
    end

    def parse_words(sentence)
        # remove punctuation
        sentence = sentence.gsub(/[\.\?!:;,"'`~—]/, "")
        words = sentence.split(/\s+/)
        return words
    end

    def print_rule(rule_id)
        @@morph.get_rule(rule_id)
    end

    def print_lemma(lemma)
        @@morph.get_lemma(lemma) 
    end

    def normalize_word(word)
        @@morph.normalize(word)
    end
end