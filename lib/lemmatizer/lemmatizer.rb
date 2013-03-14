# encoding: utf-8
require "./lib/lemmatizer/morph"

class Lemmatizer
    Entity = Struct.new(:locations, :persons, :time)
    Location = Struct.new(:geonameid, :name, :fclass, :acode, :category)
    Person = Struct.new(:name, :surname, :middlename)

    RUSSIA_ID = "2017370"

    POPULATION = "population"
    RUSSIA = "russia"
    GLOBAL = "global"
    REGIONAL = "region"

    COORDS_FMT = "%.2f,%.2f"

    POPULATION_CLASS = "P"

    def initialize
        @general_reductions = %w("т.е." "см." "т.к." "т.н." "напр." "т.г." "т.о.")
        @geo_reductions = {
          "г. "    => "город ",
          "ул. "   => "улица ",
          "с. "    => "село ",
          "пр. "   => "проспект ",
          "пл. "   => "площадь ",
          "пос. "  => "поселок ",
          "м. "    => "метро ",
          "респ. " => "республика ",
          "обл. "  => "область ",
          "РФ "    => "Россия "
        }

        @morph = Morph.new()
        @morph.load_dictionary("./dicts/morphs.mrd", "./dicts/rgramtab.tab")
        @administative_units = [ %w(ОБЛАСТЬ йж), %w(КРАЙ йа), %w(РАЙОН йа),
                                 %w(МОРЕ йм), %w(ОКРУГ йа), %w(ОЗЕРО йм),
                                 %w(УЛИЦА йж), %w(БУЛЬВАР йа), %w(ПРОСПЕКТ йа),
                                 %w(ОСТРОВА й)]
    end

    def inspect
        "Lemmatizer"
    end

    def define_location(text)
        sentences = parse_sentences(text)
        entities = []

        # parse sentences of feeds entry, result is table
        # | SENTENCE  |   LOCATION   |   PERSON   |   TIME   |
        # -----------+--------------+------------+-----------|
        # |   0       |    Moscow    |   Putin    | Februry 1|
        # |   1       |St. Petersburg|     -      |    -     |
        # ...
        sentences.each do |s|
            words = parse_words(s)

            # define normal forms for all words in sentence
            # format is array of hashes { "word" => word, "normal_form" => normal_form, "is_location" => true|false }
            normal_sentence = @morph.normalize_words(words)

            entity = Entity.new
            locations = []
            persons = []

            prev_word = {}
            normal_sentence.each_with_index do |w, index|
                #puts w
                person  = Person.new

                if @morph.is_surname?(w)
                    person.surname = w[:normal_form]
                end

                unless person.none?
                    persons << person
                end

                adjective_locations = 0
                if w[:rule] == 2
                    puts w
                    # try to search lemma in Geonames DB
                    possible_locations(w[:lemma]).each do |pl|
                        adjective_locations += 1
                        locations << pl
                    end
                end

                # check for areas or regions
                @administative_units.each do |adm_unit|
                    if w[:normal_form] == adm_unit[0] and prev_word.present?
                        0.upto(adjective_locations).each do |adj|
                            locations.pop
                        end

                        t_word = @morph.transform_word(prev_word[:lemma], prev_word[:rule], adm_unit[1])

                        unless t_word.blank?
                            possible_locations(t_word + ' ' + w[:normal_form]).each do |pl|
                                locations << pl
                            end
                        end
                    end
                end

                if w[:is_location]
                    # check for surnames around word (i.e. Vladimir is a city but Vladimir Putin - no! )
                    unless @morph.is_surname?(normal_sentence[index - 1]) or
                        @morph.is_surname?(normal_sentence[index + 1])

                        possible_locations(w[:normal_form]).each do |pl|
                            locations << pl
                        end
                    end
                end

                prev_word = w
            end

            entity.locations = locations
            entity.persons = persons
            entity.time = nil

            entities << entity
        end

        self.define_locations_weights(entities)
    end

    # returns 3 best locations based on population, number of occurencies in text and other factors
    def define_locations_weights(entities)
        locations = []
        locations_weights = {}
        is_areas = false
        is_populations = false

        max_population = 0
        max_population_location = nil

        ru_location = nil

        entities.each do |entity|
            entity.locations.each do |location|
                locations << location
                locations_weights[location] = 0.5

                if location.category == GLOBAL
                    locations_weights[location] = 0.7
                else
                    if location.category == RUSSIA
                        ru_location = location
                    end

                    location_unit = Geonames.where("geonameid = '#{location.geonameid}'").first

                    if not is_areas and location.fclass != POPULATION_CLASS
                        is_areas = true
                    end

                    if location.fclass == POPULATION_CLASS
                        is_populations = true
                        if location_unit.population > max_population
                            max_population = location_unit.population
                            max_population_location = location
                        end
                    end
                end
            end
        end

        # delete Russia from location if there are russian areas or towns in locations
        if ru_location.present? and (is_areas or is_populations)
            locations_weights.delete(ru_location)
        end

        unless max_population_location.nil?
            locations_weights[max_population_location] = 0.9
        end

        if locations.count == 1
            locations_weights[locations.first] = 0.95
        else
            locations.each do |location|
                if locations.count(location) > 1
                    locations_weights[location] = 0.8
                end

                if location.fclass == POPULATION_CLASS
                    flag = false

                    # remove areas which contain this population
                    locations.each do |l|
                        if l.acode == location.acode and l.fclass != POPULATION_CLASS
                            locations_weights[location] = 0.8
                            locations_weights.delete(l)
                            locations.delete(l)

                            flag = true
                        end
                    end

                    if flag
                        # save only population which belongs to some area
                        # and delete other populations with that name
                        locations.each do |loc|
                            if loc.name == location.name and loc.geonameid != location.geonameid
                                locations_weights.delete(loc)
                                locations.delete(loc)
                            end
                        end
                    end

                    if not flag and not is_areas and locations_weights[location] < 0.7
                        locations_weights[location] = 0.7
                    end
                end
            end
        end

        # if there are populations with same names
        # save only one with max population
        locations.each do |loc|
            if loc.category == GLOBAL
                locations.each do |loc2|
                    if loc2.category == GLOBAL and loc.name == loc2.name and loc.geonameid != loc2.geonameid
                        locations_weights.delete(loc2)
                        locations.delete(loc2)
                    end
                end
            else
                unit = Geonames.where("geonameid = '#{loc.geonameid}'").first
                locations.each do |loc2|
                    if loc2.category != GLOBAL and loc.name == loc2.name and loc.geonameid != loc2.geonameid
                        unit2 = Geonames.where("geonameid = '#{loc2.geonameid}'").first
                        if unit.population > unit2.population
                            locations_weights.delete(loc2)
                            locations.delete(loc2)
                        end
                    end
                end
            end
        end

        locations_weights.sort_by {|k,v| v}.reverse[0...3]
    end

    def possible_locations(location)
        locations = []

        units = Geonames.where('name ~* ?', "^#{location}$|^#{location}[,]|[,]#{location}[,]|[,]#{location}$")

        unless units.empty?
            units.each do |unit|
                loc = Location.new
                loc.geonameid = unit.geonameid
                loc.name = location
                loc.acode = unit.acode
                loc.fclass = unit.fclass

                if unit.fclass == POPULATION_CLASS
                    loc.category = POPULATION
                elsif unit.geonameid == RUSSIA_ID
                    loc.category = RUSSIA
                else
                    loc.category = REGIONAL
                end
                locations << loc
            end
        end

        countries = Countries.where('name ~* ?', "^#{location}$|^#{location}[,]|[,]#{location}[,]|[,]#{location}$")
        if countries.empty?
            capitals = Countries.where('capital ~* ?', "^#{location}$|^#{location}[,]|[,]#{location}[,]|[,]#{location}$")

            unless capitals.empty?
                capitals.each do |capital|
                    loc = Location.new
                    loc.name = location
                    loc.geonameid = capital.id
                    loc.category = GLOBAL
                    locations << loc
                end
            end
        else
            countries.each do |country|
                loc = Location.new
                loc.name = location
                loc.geonameid = country.id
                loc.category = GLOBAL
                locations << loc
            end
        end

        locations
    end

    def define_location_coords(location)
        result = Location.new
        adm_units = []
        population_units = []

        # search location in Geonames database
        units = Geonames.where('name ~* ?', "^#{location}$|^#{location}[,]|[,]#{location}[,]|[,]#{location}$")

        # split possible locations by class (towns or areas)
        units.each do |unit|
            if unit.fclass == POPULATION_CLASS
                population_units << unit
            else
                adm_units << unit
            end
        end

        # choose settlement with max population or administrative region with minimal population
        if population_units.empty?
            unless adm_units.empty?
                unit = adm_units.last

                if unit.geonameid == RUSSIA_ID
                    result.geonameid = unit.geonameid
                    result.name = location
                    result.acode = unit.acode
                    result.category = RUSSIA
                    result.fclass = unit.fclass
                    return result
                else
                    result.geonameid = unit.geonameid
                    result.name = location
                    result.acode = unit.acode
                    result.category = REGIONAL
                    result.fclass = unit.fclass
                    return result
                end
            end
        else
            unit = population_units.first
            result.name = location
            result.geonameid = unit.geonameid
            result.acode = unit.acode
            result.category = POPULATION
            result.fclass = unit.fclass
            return result
        end

        # if location isn't defined try to search it in countries database
        countries = Countries.where('name ~* ?', "^#{location}$|^#{location}[,]|[,]#{location}[,]|[,]#{location}$")

        if countries.empty?
            capitals = Countries.where('capital ~* ?', "^#{location}$|^#{location}[,]|[,]#{location}[,]|[,]#{location}$")

            unless capitals.empty?
                unit = capitals.first
                result.name = location
                result.geonameid = unit.id
                result.category = GLOBAL
            end

        else
            unit = countries.first
            result.name = location
            result.geonameid = unit.id
            result.category = GLOBAL
        end

        result
    end

    def define_coords(locations)
        adm_units = []
        population_units = []

        locations.each do |location|
            # search location in Geonames database
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
                loc_coords = "%.2f,%.2f" % [adm_units.last[0].latitude, adm_units.last[0].longitude]
                if loc_coords == RU_LOC
                    return {coords: loc_coords, name: adm_units.last[1], category: "russia"}
                else
                    return {coords: loc_coords, name: adm_units.last[1], category: "region"}
                end
            end
        else
            loc_coords = "%.2f,%.2f" % [population_units.first[0].latitude, population_units.first[0].longitude]
            return {coords: loc_coords, name: population_units.first[1], category: "population"}
        end

        # if location isn't defined try to search it in countries database
        locations.each do |location|
            countries = Countries.where('name ~* ?', "^#{location}$|^#{location}[,]|[,]#{location}[,]|[,]#{location}$")

            if countries.empty?
                capitals = Countries.where('capital ~* ?', "^#{location}$|^#{location}[,]|[,]#{location}[,]|[,]#{location}$")

                unless capitals.empty?
                    coords = "%.2f,%.2f" % [capitals[0].latitude, capitals[0].longitude]
                    return {coords: coords, name: capitals[0].capital, category: "global"}
                end

            else
                coords = "%.2f,%.2f" % [countries[0].latitude, countries[0].longitude]
                return {coords: coords, name: countries[0].name, category: "global"}
            end
        end

        {coords: nil, name: nil, category: nil}
    end

    def parse_sentences(text)
        text = text.strip

        # remove all reductions from sentences, beacause it isn't influence on semantic meaning 
        # and ease parsing text on sentences
        @general_reductions.each do |gd|
            text = text.gsub(gd, "")
        end

        ## replace geo reductions with full name in first form
        #@geo_reductions.each do |key, value|
        #    text = text.gsub(key, value)
        #end

        text.split(/(?![а-яА-Я])(?<=\.|\!|\?)(?!\")\s+(?=\"?[А-Я])/)
    end

    def parse_words(sentence)
        # remove punctuation
        sentence = sentence.gsub(/[\.\?!:;,`~—]/, "")
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