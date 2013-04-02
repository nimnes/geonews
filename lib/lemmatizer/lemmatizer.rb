# encoding: utf-8
require './lib/lemmatizer/morph'

class Lemmatizer
    Entity = Struct.new(:locations, :persons, :time)
    Location = Struct.new(:geonameid, :name, :fclass, :acode, :category, :population, :source)
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
        @administative_units = [ %w(ОБЛАСТЬ ЖР), %w(КРАЙ МР), %w(РАЙОН МР),
                                 %w(МОРЕ СР), %w(ОКРУГ МР), %w(ОЗЕРО СР),
                                 %w(УЛИЦА ЖР), %w(БУЛЬВАР МР), %w(ПРОСПЕКТ МР),
                                 %w(ОСТРОВА МН)]
        @rule_classes = ['NOUN', 'С', 'ADJECTIVE', 'П', 'КР_ПРИЛ']
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

            skip_iterations = 0

            normal_sentence.each_with_index do |w, index|
                if skip_iterations > 0
                    next
                end

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

                next_word = normal_sentence[index + 1]

                if next_word.present? and @rule_classes.include?(@morph.get_word_class(w))
                    # check for areas or regions
                    @administative_units.each do |adm_unit|
                        if next_word[:normal_form] == adm_unit[0]
                            t_word = @morph.transform_word(w[:lemma], w[:rule], adm_unit[1])

                            unless t_word.blank?
                                # delete adjective locations if there is area keyword after it
                                0.upto(adjective_locations).each do |adj|
                                    locations.pop
                                end

                                self.possible_locations(t_word + ' ' + next_word[:normal_form]).each do |pl|
                                    locations << pl
                                end
                            end

                            skip_iterations += 1
                            break
                        end
                    end

                    if skip_iterations > 0
                        next
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
                else
                    if @rule_classes.include?(@morph.get_word_class(w))
                        # check user rules
                        user_rule = UserRules.where('rule = ?', w[:normal_form]).first
                        if user_rule.present?
                            loc = get_location(user_rule.referent)
                            loc.name = UnicodeUtils.upcase(user_rule.toponym)
                            loc.source = USER_RULES
                            locations << loc
                        end
                    end
                end
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
                    # use prefix because of three DBs: Countries (World), WorldCities and Geonames (Russia)
                    if location.source == COUNTRIES_DB
                        referents += 'c' + location.geonameid.to_s + ';'
                    elsif location.source == WORLD_CITIES_DB
                        referents += 'w' + location.geonameid.to_s + ';'
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

                    loc = get_location(best[0].referents.split(';').first)
                    loc.name = best[0].toponym
                    loc.source = LEARNING

                    best_locations << [loc, best[1]]
                end
            end
        end

        best_locations
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

                if location.category == COUNTRY or location.category == WORLD_POPULATION
                    locations_weights[location] = 0.75
                else
                    if location.category == RUSSIA
                        ru_location = location
                    end

                    if not is_areas and location.fclass != POPULATION_CLASS
                        is_areas = true
                    end

                    if location.fclass == POPULATION_CLASS
                        is_populations = true
                        if location.population > max_population
                            max_population = location.population
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
                            locations_weights[location] = 0.9
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

        deleted = []

        # if there are populations with same names
        # save only one with max population
        locations.each_with_index do |loc, index|
            if deleted.include?(loc)
                next
            end

            (index + 1).upto(locations.count - 1) do |index2|
                loc2 = locations[index2]
                if loc.name == loc2.name and loc != loc2
                    # global toponyms have more priority than russian
                    if loc2.category == COUNTRY
                        deleted << loc2
                    else
                        if loc.population >= loc2.population
                            deleted << loc2
                        else
                            deleted << loc
                        end
                    end
                end
            end
        end

        deleted.each do |d|
            locations.delete(d)
            locations_weights.delete(d)
        end

        locations_weights.sort_by {|k,v| v}.reverse[0...3]
    end

    def possible_locations(location)
        locations = []

        if location.blank?
            return locations
        end

        # russian cities and areas
        units = Geonames2.where('name ~* ?', "^#{location}$|^#{location}[,]|[,]#{location}[,]|[,]#{location}$")

        unless units.empty?
            units.each do |unit|
                loc = Location.new
                loc.geonameid = unit.geonameid
                loc.name = location
                loc.acode = unit.acode
                loc.fclass = unit.fclass
                loc.source = GEONAMES_DB
                loc.population = unit.population

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

        # other countries and their capitals
        countries = Countries.where('name ~* ?', "^#{location}$|^#{location}[,]|[,]#{location}[,]|[,]#{location}$")
        if countries.empty?
            capitals = Countries.where('capital ~* ?', "^#{location}$|^#{location}[,]|[,]#{location}[,]|[,]#{location}$")

            capitals.each do |capital|
                loc = Location.new
                loc.name = location
                loc.geonameid = capital.id
                loc.category = COUNTRY
                loc.source = COUNTRIES_DB
                loc.population = 0
                locations << loc
            end
        else
            countries.each do |country|
                loc = Location.new
                loc.name = location
                loc.geonameid = country.id
                loc.category = COUNTRY
                loc.source = COUNTRIES_DB
                loc.population = 0
                locations << loc
            end
        end

        if locations.empty?
            # not russian big cities
            cities = WorldCities.where('name ~* ?', "^#{location}$|^#{location}[,]|[,]#{location}[,]|[,]#{location}$")

            cities.each do |city|
                loc = Location.new
                loc.name = location
                loc.geonameid = city.geonameid
                loc.source = WORLD_CITIES_DB
                loc.category = WORLD_POPULATION
                loc.population = city.population
                locations << loc
            end
        end

        locations
    end

    def get_location_name(location_id)
        if location_id.start_with?('g')
            Geonames2.where('geonameid = ?', location_id[1..-1]).first.name
        else
            Countries.find(location_id[1..-1]).name
        end
    end

    def get_location(location_id)
        loc = Location.new
        loc.geonameid = location_id[1..-1]

        if location_id.start_with?('g')
            unit = Geonames2.where('geonameid = ?', loc.geonameid).first

            if unit.fclass == POPULATION_CLASS
                loc.category = POPULATION
            elsif unit.geonameid == RUSSIA_ID
                loc.category = RUSSIA
            else
                loc.category = REGIONAL
            end

            loc.population = unit.population
            loc.fclass = unit.fclass
            loc.acode = unit.acode
        elsif location_id.start_with?('w')
            unit = WorldCities.where('geonameid = ?', loc.geonameid).first
            loc.population = unit.population
            loc.category = WORLD_POPULATION
        else
            loc.population = 0
            loc.category = COUNTRY
        end

        loc
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
        sentence = sentence.gsub(/[\(\)\.\?!:;,`~]/, '')
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