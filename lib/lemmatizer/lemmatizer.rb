# encoding: utf-8
require './lib/lemmatizer/morph'

class String
    def is_upper?
        self == UnicodeUtils.upcase(self)
    end
end

class Lemmatizer
    Entity = Struct.new(:locations, :persons, :time)
    Location = Struct.new(:geonameid, :name, :fclass, :acode, :category, :population, :source)
    Person = Struct.new(:name, :surname, :middlename)
    Context = Struct.new(:toponym, :left, :right)

    def initialize
        @general_reductions = %w("т.е." "см." "т.к." "т.н." "напр." "т.г." "т.о.")
        @geo_reductions = {
          ' г.'    => ' город',
          ' ул.'   => ' улица',
          ' с.'    => ' село',
          ' пр.'   => ' проспект',
          ' пл.'   => ' площадь',
          ' пос.'  => ' поселок',
          ' м.'    => ' метро',
          ' респ.' => ' республика',
          ' обл.'  => ' область'
        }

        @administrative_units = [
            %w(ОБЛАСТЬ ЖР), %w(КРАЙ МР), %w(РАЙОН МР),
            %w(РЕГИОН МР), %w(ПЛОЩАДЬ ЖР),
            %w(МОРЕ СР), %w(ОКРУГ МР), %w(ОЗЕРО СР),
            %w(УЛИЦА ЖР), %w(БУЛЬВАР МР), %w(ПРОСПЕКТ МР),
            %w(ОСТРОВА МН), %w(ФЕДЕРАЦИЯ ЖР),
            %w(ВОСТОК МР), %w(ШОССЕ СР),
            %w(ВОКЗАЛ МР), %w(СОБОР МР), %w(ЦЕРКОВЬ ЖР)
        ]

        @geo_modificators = ['ДАЛЬНИЙ', 'НИЖНИЙ', 'ВЕЛИКИЙ', 'СЕВЕРНЫЙ', 'ЮЖНЫЙ']
        @rule_classes = ['NOUN', 'С', 'ADJECTIVE', 'П', 'КР_ПРИЛ']

        @morph = Morph.new()
        @morph.load_dictionary('./dicts/morphs.mrd', './dicts/rgramtab.tab')

        LearningCorpus.create_corpus
    end

    def inspect
        'Lemmatizer'
    end

    def define_location(text, entry_id = nil)
        sentences = parse_sentences(text)
        entities = []
        persons = []

        # parse sentences of feeds entry, result is table of locations sorted by score
        # |    LOCATION    |   SCORE   |
        # |----------------+-----------|
        # |     Moscow     |    0.95   |
        # | St. Petersburg |    0.8    |
        # |      ...       |    ...    |
        sentences.each do |s|
            words = parse_words(s)

            # define normal forms for all words in sentence
            # format is array of hashes { "word" => word, "normal_form" => normal_form, "is_location" => true|false }
            normal_sentence = @morph.normalize_words(words)

            entity = Entity.new
            locations = []

            skip_iterations = 0
            prev_word = nil

            normal_sentence.each_with_index do |w, index|
                if skip_iterations > 0
                    skip_iterations -= 1
                    next
                end

                # save persons form entry for future recognizing entries with learning
                if w.word.first.is_upper? and @morph.is_surname?(w)
                    persons << w.normal
                end

                next_word = normal_sentence[index + 1]

                # check for areas or regions
                if next_word.present? and @rule_classes.include?(@morph.get_word_class(w))
                    @administrative_units.each do |adm_unit|
                        if next_word.normal == adm_unit[0]
                            t_word = @morph.transform_word(w.lemma, w.rule, adm_unit[1])

                            ## delete adjective locations if there is area keyword after it
                            #0.upto(adjective_locations - 1).each do |adj|
                            #    locations.pop
                            #end

                            unless t_word.blank?
                                self.possible_locations(t_word + ' ' + next_word.normal).each do |pl|
                                    locations << pl
                                end
                            end

                            skip_iterations += 1
                            break
                        end
                    end

                    if skip_iterations > 0
                        skip_iterations -= 1
                        next
                    end
                end

                # check user rules
                if @rule_classes.include?(@morph.get_word_class(w))
                    user_rules = UserRules.where('rule ~* ?', "^#{w.normal}$|^#{w.normal}[,]")

                    if user_rules.present?
                        user_rules.each do |ur|
                            rule_words = ur.rule.split(',')

                            rw_ind = 0
                            tmp_word = w.normal

                            while rw_ind < rule_words.count and tmp_word == rule_words[rw_ind]
                                rw_ind += 1
                                if normal_sentence[index + rw_ind].nil?
                                    break
                                else
                                    tmp_word = normal_sentence[index + rw_ind].normal
                                end
                            end

                            if rw_ind == rule_words.count
                                if ur.ruletype == PLACE
                                    loc = get_location(ur.referent)
                                    loc.name = UnicodeUtils.upcase(ur.toponym)
                                    loc.source = USER_RULES
                                    locations << loc
                                else
                                    skip_iterations += rule_words.count
                                    if skip_iterations > 0
                                        skip_iterations -= 1
                                        next
                                    end
                                end
                            end
                        end
                    end
                end

                adjective_locations = 0

                # rule 2 - most common rule for adjectives
                # adjectives may contain locations (i.e. Russians => Russia)
                if w.rule == 2 and (not w.word.first.is_upper? or index == 0)
                    lemma = w.lemma
                    k = 0

                    # get lemma of word and try to find location with name as lemma in dictionary
                    # allow only locations with MINIMAL_POPULATION (default: 50000 people)
                    # it helps to filter wrong locations (Kirovskyy => Kirov, not Kirovsk)
                    # if no canditates found cut last letter of lemma (Kirovsk => Kirov)
                    while adjective_locations == 0 and k <= 2
                        lemma = lemma[0...-1] if k > 0
                        normal_form = @morph.normalize_word(lemma)

                        if not normal_form.nil? and normal_form.is_location
                            self.possible_locations(lemma).each do |pl|
                                if pl.population >= MIN_ADJ_POPULATION or
                                    pl.source == COUNTRIES_DB or pl.source == WORLD_CITIES_DB
                                    adjective_locations += 1
                                    locations << pl
                                    break
                                end
                            end
                        end

                        k += 1
                    end

                    # one more try :)
                    # most popular rules
                    if k == 3 and adjective_locations == 0
                        suffixes = ['Ь', 'ИЯ', 'А']

                        s = 0
                        while adjective_locations == 0 and s < suffixes.count
                            lemma_tmp = lemma + suffixes[s]
                            normal_form = @morph.normalize_word(lemma_tmp)

                            if not normal_form.nil? and normal_form.is_location
                                self.possible_locations(lemma_tmp).each do |pl|
                                    if pl.population >= MIN_ADJ_POPULATION or
                                        pl.source == COUNTRIES_DB or pl.source == WORLD_CITIES_DB
                                        adjective_locations += 1
                                        locations << pl
                                    end
                                end
                            end

                            s += 1
                        end

                        if adjective_locations == 0
                            if lemma.end_with?('Й')
                                lemma_tmp = lemma
                                lemma_tmp[lemma_tmp.length - 1] = 'Я'

                                self.possible_locations(lemma).each do |pl|
                                    if pl.population >= MIN_ADJ_POPULATION or
                                        pl.source == COUNTRIES_DB or pl.source == WORLD_CITIES_DB
                                        adjective_locations += 1
                                        locations << pl
                                    end
                                end
                            end
                        end
                    end
                end

                # check for words with modificators
                # i.e. North Korea, South Korea
                if next_word.present? and @rule_classes.include?(@morph.get_word_class(next_word))
                    if @geo_modificators.include?(w.normal)
                        t_word = @morph.transform_word(w.lemma, w.rule, @morph.get_word_kind(next_word))

                        unless t_word.blank?
                            self.possible_locations(t_word + ' ' + next_word.normal).each do |pl|
                                locations << pl
                            end
                        end

                        skip_iterations += 1
                        next
                    end
                end

                if w.is_location
                    # location name must start with uppercase letter
                    if w.word.first.is_upper? or index == 0

                        unless @morph.check_coherence(prev_word, w)
                            next
                        end

                        if @morph.is_surname?(normal_sentence[index + 1]) or @morph.is_name?(normal_sentence[index - 1])
                            next
                        end

                        self.possible_locations(w.normal).each do |pl|
                            locations << pl
                        end
                    end
                end

                prev_word = w
            end

            entity.locations = locations
            entity.time = nil

            entities << entity
        end

        best_locations = self.define_locations_weights(entities)

        if best_locations.present?
            self.add_to_learning_corpus(text, best_locations, persons, entry_id)
            return best_locations
        else
            # try to find similar entries in Learning corpus
            if LearningCorpus.consistent?
                # by entry context
                context = @morph.remove_stop_words(@morph.normalize_words(parse_words(text)))
                similar_entries = LearningCorpus.get_similar_entries(context)

                if similar_entries.present?
                    best = similar_entries.first

                    entry = LearningCorpus.where('entryid = ?', best[0]).first

                    if entry.present?
                        loc = get_location(entry.referents.split(';').first)
                        loc.name = entry.toponym

                        loc.source = LEARNING

                        best_locations << [loc, best[1]]
                    end
                else
                    # by persons from entry
                    similar_person_entries = LearningCorpus.get_entries_with_persons(persons)

                    if similar_person_entries.present?
                        best_location = most_common_value(similar_person_entries.keys)
                        loc = get_location(best_location)
                        loc.name = similar_person_entries[best_location]
                        loc.source = LEARNING

                        best_locations << [loc, 0.9]

                        #puts entry_id.to_s + ' ' + loc.name + ' ' + persons.to_s
                    end
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

        ru_locations = []

        entities.each do |entity|
            entity.locations.each do |location|
                locations << location
                locations_weights[location] = 0.5

                if location.category == COUNTRY
                    locations_weights[location] = 0.75
                else
                    if location.category == RUSSIA
                        unless ru_locations.include?(location)
                            ru_locations << location
                        end
                    elsif not is_areas and location.fclass != POPULATION_CLASS
                        is_areas = true
                    end

                    if location.category != WORLD_POPULATION and location.fclass == POPULATION_CLASS
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
        if ru_locations.present? and (is_areas or is_populations)
            ru_locations.each do |ru_loc|
                locations_weights.delete(ru_loc)
                locations.delete(ru_loc)
            end
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

                if deleted.include?(loc2)
                    next
                end

                if loc.name == loc2.name and loc != loc2
                    if loc.fclass == ADMINISTRATIVE_CLASS and loc2.fclass == POPULATION_CLASS
                        deleted << loc2
                        next
                    end

                    # global toponyms have more priority than russian
                    if loc2.category == COUNTRY
                        deleted << loc
                    else
                        if loc.population >= loc2.population
                            deleted << loc2
                        else
                            deleted << loc
                        end
                    end
                end

                # delete similar locations with different names
                if loc.geonameid == loc2.geonameid and loc.name != loc2.name
                    deleted << loc2
                end
            end
        end

        deleted.each do |d|
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
        units = Geonames.where('name ~* ?', "^#{location}$|^#{location}[,]|[,]#{location}[,]|[,]#{location}$")

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
        if countries.present?
            countries.each do |country|
                loc = Location.new
                loc.name = location
                loc.geonameid = country.id
                loc.acode = country.code
                loc.category = COUNTRY
                loc.source = COUNTRIES_DB
                loc.population = 0
                locations << loc
            end
        #else
        #    capitals = Countries.where('capital ~* ?', "^#{location}$|^#{location}[,]|[,]#{location}[,]|[,]#{location}$")
        #
        #    capitals.each do |capital|
        #        loc = Location.new
        #        loc.name = location
        #        loc.geonameid = capital.id
        #        loc.category = WORLD_POPULATION
        #        loc.fclass = capital.code
        #        loc.source = COUNTRIES_DB
        #        loc.population = 0
        #        locations << loc
        #    end
        end
        #
        ##if locations.empty?
            # not russian big cities
            cities = WorldCities.where('name ~* ?', "^#{location}$|^#{location}[,]|[,]#{location}[,]|[,]#{location}$")

            cities.each do |city|
                loc = Location.new
                loc.name = location
                loc.acode = city.countrycode
                loc.fclass = POPULATION_CLASS
                loc.geonameid = city.geonameid
                loc.source = WORLD_CITIES_DB
                loc.category = WORLD_POPULATION
                loc.population = city.population
                locations << loc
            end
        ##end

        locations
    end

    def get_location_name(location_id)
        if location_id.start_with?('g')
            Geonames.where('geonameid = ?', location_id[1..-1]).first.name
        else
            Countries.find(location_id[1..-1]).name
        end
    end

    def get_location(location_id)
        loc = Location.new
        loc.geonameid = location_id[1..-1]

        if location_id.start_with?('g')
            unit = Geonames.where('geonameid = ?', loc.geonameid).first

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
            loc.acode = unit.countrycode
            loc.fclass = POPULATION_CLASS
        else
            unit = Countries.find(loc.geonameid)
            loc.population = 0
            loc.category = COUNTRY
            loc.acode = unit.code
        end

        loc
    end

    def add_to_learning_corpus(text, locations, persons, entry_id)
        # add resolved entries to LearningCorpus
        if entry_id.present? and not LearningCorpus.has_entry?(entry_id)
            referents = ''

            locations.each do |location, score|
                # use prefix because of three DBs: Countries (World), WorldCities and Geonames (Russia)
                if location.source == COUNTRIES_DB
                    referents += 'c' + location.geonameid.to_s + ';'
                elsif location.source == WORLD_CITIES_DB
                    referents += 'w' + location.geonameid.to_s + ';'
                elsif location.source == GEONAMES_DB
                    referents += 'g' + location.geonameid.to_s + ';'
                end
            end

            unless referents.blank?
                referents = referents[0...-1]

                context = @morph.remove_stop_words(@morph.normalize_words(parse_words(text)))
                LearningCorpus.add_entry(context, locations.first[0].name, referents, persons, entry_id)
            end
        end
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

    def most_common_value(a)
        a.group_by do |e|
            e
        end.values.max_by(&:size).first
    end
end