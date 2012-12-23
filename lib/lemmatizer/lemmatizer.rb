# encoding: utf-8
require "./lib/lemmatizer/morph"

class Lemmatizer
    Location = Struct.new(:latitude, :longitude)

    def initialize
        @general_reductions = %w("т.е." "см." "т.к." "т.н." "напр." "т.г." "т.о.")
        @geo_reductions = {
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

        @morph = Morph.new()
        @morph.load_dictionary("./dicts/morphs.mrd", "./dicts/rgramtab.tab")
        @administative_units = [%w(ОБЛАСТЬ йж), %w(КРАЙ йа)]
    end

    def inspect
        "Lemmatizer"
    end

    def define_location(text)
        sentences = parse_sentences(text)
        locations = []

        sentences.each do |s|
            words = parse_words(s)

            # define normal forms for all words in sentence
            # format is array of hashes { "word" => word, "normal_form" => normal_form, "is_location" => true|false }
            normal_sentence = @morph.normalize_words(words)

            prev_word = {}
            normal_sentence.each do |w|
                # check for areas or regions
                @administative_units.each do |adm_unit|
                    if w[:normal_form] == adm_unit[0] and prev_word.present?
                        t_word = @morph.transform_word(prev_word[:lemma], prev_word[:rule], adm_unit[1])

                        unless t_word.blank?
                            locations <<  t_word + " " + w[:normal_form]
                        end
                    end
                end

                locations << w[:normal_form] if w[:is_location]

                prev_word = w
            end
        end

        #locations
        define_coords(locations)
    end

    def define_location_full(text)
        sentences = parse_sentences(text)
        locations = []

        sentences.each do |s|
            words = parse_words(s)

            # define normal forms for all words in sentence
            # format is array of hashes { "word" => word, "normal_form" => normal_form, "is_location" => true|false }
            normal_sentence = @morph.normalize_words(words)

            prev_word = {}
            normal_sentence.each do |w|
                # check for areas or regions
                @administative_units.each do |adm_unit|
                    if w[:normal_form] == adm_unit[0] and prev_word.present?
                        t_word = @morph.transform_word(prev_word[:lemma], prev_word[:rule], adm_unit[1])

                        unless t_word.blank?
                            locations <<  ["", t_word + " " + w[:normal_form]]
                        end
                    end
                end

                if w[:is_location]
                    locations << [w[:word], w[:normal_form]]
                end

                prev_word = w
            end
        end

        locations
    end

    def define_coords(locations)
        adm_units = []
        population_units = []

        locations.each do |location|
            units = Geonames.where('name ~* ?', "^#{location}$|^#{location}[,]|[,]#{location}[,]|[,]#{location}$")

            units.each do |unit|
                if unit.fclass == "P"
                    population_units << [unit, location]
                else
                    adm_units << [unit, location]
                end
            end
        end

        # choose settlement with max population or administrative region with minimal population
        if population_units.empty?
            unless adm_units.empty?
                return "%.2f,%.2f,%s" % [adm_units.last[0].latitude, adm_units.last[0].longitude, adm_units.last[1]]
            end
        else
            return "%.2f,%.2f,%s" % [ population_units.first[0].latitude,
                                     population_units.first[0].longitude,
                                     population_units.first[1] ]
        end

        ""
    end

    def parse_sentences(text)
        text = text.strip

        # remove all reductions from sentences, beacause it isn't influence on semantic meaning 
        # and ease parsing text on sentences
        @general_reductions.each do |gd|
            text = text.gsub(gd, "")
        end

        # replace geo reductions with full name in first form
        @geo_reductions.each do |key, value|
            text = text.gsub(key, value)
        end

        text.split(/(?![а-яА-Я])(?<=\.|\!|\?)(?!\")\s+(?=\"?[А-Я])/)
    end

    def parse_words(sentence)
        # remove punctuation
        sentence = sentence.gsub(/[\.\?!:;,"'`~—]/, "")
        sentence.split(/\s+/)
    end

    def print_rule(rule_id)
        @morph.get_rule(rule_id)
    end

    def print_lemma(lemma)
        @morph.get_lemma(lemma) 
    end

    def normalize_word(word)
        @morph.normalize(word)
    end
end