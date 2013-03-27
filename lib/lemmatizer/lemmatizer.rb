# encoding: utf-8
require './lib/lemmatizer/morph'

class Lemmatizer
    Entity = Struct.new(:locations, :persons, :time)
    Location = Struct.new(:geonameid, :name, :fclass, :acode, :category)
    Person = Struct.new(:name, :surname, :middlename)
    Context = Struct.new(:toponym, :left, :right)

    def initialize
        @general_reductions = %w("т.е." "см." "т.к." "т.н." "напр." "т.г." "т.о.")
        @geo_reductions = {
          'г. '    => 'город ',
          'ул. '   => 'улица ',
          'с. '    => 'село ',
          'пр. '   => 'проспект ',
          'пл. '   => 'площадь ',
          'пос. '  => 'поселок ',
          'м. '    => 'метро ',
          'респ. ' => 'республика ',
          'обл. '  => 'область ',
          'РФ '    => 'Россия '
        }

        @morph = Morph.new()
        @morph.load_dictionary('./dicts/morphs.mrd', './dicts/rgramtab.tab')
        @administative_units = [ %w(ОБЛАСТЬ йж), %w(КРАЙ йа), %w(РАЙОН йа),
                                 %w(МОРЕ йм), %w(ОКРУГ йа), %w(ОЗЕРО йм),
                                 %w(УЛИЦА йж), %w(БУЛЬВАР йа), %w(ПРОСПЕКТ йа),
                                 %w(ОСТРОВА й)]
    end

    def inspect
        'Lemmatizer'
    end

    def define_location(text, entry_id = nil)
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
                person  = Person.new

                if @morph.is_surname?(w)
                    person.surname = w[:normal_form]
                end

                unless person.none?
                    persons << person
                end

                adjective_locations = 0
                if w[:rule] == 2
                    # search lemma in dictionary
                    # if it is in locations dictionary then try to find it in Geonames or Countries DBs
                    normal_form = @morph.normalize_word(w[:lemma])

                    if not normal_form.nil? and normal_form[:is_location]
                        self.possible_locations(w[:lemma]).each do |pl|
                            adjective_locations += 1
                            locations << pl
                        end
                    end
                end

                # check for areas or regions
                @administative_units.each do |adm_unit|
                    if w[:normal_form] == adm_unit[0] and prev_word.present?
                        t_word = @morph.transform_word(prev_word[:lemma], prev_word[:rule], adm_unit[1])

                        unless t_word.blank?
                            # delete adjective locations if there is area keyword after it
                            0.upto(adjective_locations).each do |adj|
                                locations.pop
                            end

                            self.possible_locations(t_word + ' ' + w[:normal_form]).each do |pl|
                                locations << pl
                            end
                        end

                        break
                    end
                end

                if w[:is_location]
                    # check for surnames around word (i.e. Vladimir is a city but Vladimir Putin - no! )
                    unless @morph.is_surname?(normal_sentence[index - 1]) or
                        @morph.is_surname?(normal_sentence[index + 1])

                        self.possible_locations(w[:normal_form]).each do |pl|
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

        best_locations = self.define_locations_weights(entities)

        if best_locations.present?
            # add resolved entries to LearningCorpus
            if entry_id.present? and not LearningCorpus.has_entry?(entry_id)
                referents = ''

                best_locations.each do |location, score|
                    # use prefix because of two DBs: Countries (World) and Geonames (Russia)
                    if location.category == GLOBAL
                        referents += 'c' + location.geonameid.to_s + ';'
                    else
                        referents += 'g' + location.geonameid.to_s + ';'
                    end
                end

                unless referents.blank?
                    referents = referents[0...-1]

                    context = @morph.remove_stop_words(@morph.normalize_words(parse_words(text)))
                    LearningCorpus.add_entry(context, best_locations.first[0].name, referents, entry_id)
                end
            end

            return best_locations
        else
            # try to find similar entries in Learning corpus
            if LearningCorpus.consistent?
                context = @morph.remove_stop_words(@morph.normalize_words(parse_words(text)))
                similar_entries = LearningCorpus.get_similar_entries(context)

                if similar_entries.present?
                    best = similar_entries.first

                    loc = Location.new
                    loc.geonameid = best[0].referents.split(';').first
                    loc.name = best[0].toponym
                    loc.category = 'predicted'

                    best_locations << [loc, best[1]]
                end
            end
        end

        best_locations

        #unless learning_items.empty?
        #    referents = ''
        #
        #    best_locations.each do |loc|
        #        # use prefix because of two DBs: Countries (World) and Geonames (Russia)
        #        if loc[0].category == GLOBAL
        #            referents += 'c' + loc[0].geonameid.to_s + ';'
        #        else
        #            referents += 'g' + loc[0].geonameid.to_s + ';'
        #        end
        #    end
        #
        #    if referents.blank?
        #        return best_locations
        #    else
        #        referents = referents[0...-1]
        #    end
        #
        #    learning_items.each do |litem|
        #        LearningCorpus.add_toponym(litem, referents, entry_id)
        #    end
        #end

        ## if location is undefined, try to find similar entities in learning corpus
        #if best_locations.empty?
        #    unless predicted_locations.empty?
        #        predicted_locations = predicted_locations.sort_by {|x,y| y}[0...3]
        #
        #        predicted_locations.each do |pl, score|
        #            puts 'L: ' + pl.left + ' R: ' + pl.right + ' T: ' + pl.toponym + ' R: ' + pl.referents
        #            loc = Location.new
        #            loc.geonameid = pl.referents.split(';').first
        #            loc.name = pl.toponym
        #            loc.category = 'predicted'
        #
        #            best_locations << [loc, score]
        #        end
        #
        #        return best_locations
        #    end
        #else
        #    best_locations
        #end
    end

    def get_location_name(location_id)
        if location_id.start_with?('g')
            Geonames.where('geonameid = ?', location_id[1..-1]).first.name
        else
            Countries.find(location_id[1..-1]).name
        end
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

        if location.blank?
            return locations
        end

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

    def parse_sentences(text)
        text = text.strip

        # remove all reductions from sentences, beacause it isn't influence on semantic meaning 
        # and ease parsing text on sentences
        @general_reductions.each do |gd|
            text = text.gsub(gd, '')
        end

        ## replace geo reductions with full name in first form
        @geo_reductions.each do |key, value|
            text = text.gsub(key, value)
        end

        text.split(/(?![а-яА-Я])(?<=\.|!|\?)(?!")\s+(?="?[А-Я])/)
    end

    def parse_words(sentence)
        # remove punctuation
        sentence = sentence.gsub(/[\(\)\.\?!:;,`~—]/, '')
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