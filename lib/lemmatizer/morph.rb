# encoding: utf-8
require 'unicode_utils/upcase'
require 'benchmark'

class Morph
    Token = Struct.new(:word, :normal, :lemma, :rule, :rule_part, :annotation, :is_location)
    Rule = Struct.new(:suffix, :gram, :prefix)
    Annotation = Struct.new(:rule, :prefix, :gram)

    def initialize
        @rules = []
        @rule_frequencies = []
        @prefixes = []
        @lemmas = Containers::Trie.new
        @endings = Containers::Trie.new
        @gramtab = {}

        @productive_classes = ['NOUN', 'С', 'Г', 'ИНФИНИТИВ', 'VERB', 'ADJECTIVE', 'П', 'Н', 'КР_ПРИЛ']
        @context_classes = ['NOUN', 'С', 'ADJECTIVE', 'П', 'КР_ПРИЛ']

        # for transform_word function
        @kinds = {
            'МР' => ['йа', 'аа', 'Юо', 'го'],
            'ЖР' => ['йж', 'га', 'Йа', 'Йм'],
            'СР' => ['йм', 'еа', 'Яз'],
            'МН' => ['йт']
        }
    end

    def load_dictionary(dict_file, gram_file)
        puts '[LEM] loading dictionary ' + dict_file + ' with gramtab ' + gram_file + '...'

        dictionary_file = File.new(dict_file, 'r')
        gramtab_file = File.new(gram_file, 'r')

        time = Benchmark.realtime do
            read_dictionary(dictionary_file)
        end
        puts "[LEM] dictionary was loaded in #{'%.3f' % time} seconds"

        time = Benchmark.realtime do
            read_gramtab(gramtab_file)
        end
        puts "[LEM] gramtab file was loaded in #{'%.3f' % time} seconds"

    end

    def read_section(file)
        section_length = file.gets.to_i
        section_lines = []

        (1..section_length).each do |i|
            section_lines[i - 1] = file.gets
        end

        section_lines
    end

    def pass_section(file)
        read_section(file).each {
        }
    end

    def load_rules(file)
        section_lines = read_section(file)

        rule_id = 0
        section_lines.each do |line|
            line_rules = line.strip().split('%')

            tmp_rules = []
            line_rules.each do |r|
                if r.blank?
                    next
                end

                rule_parts = r.split('*')
                rule_parts[2] = '' if rule_parts.count == 2

                rule = Rule.new
                rule.suffix = rule_parts[0]
                rule.gram = rule_parts[1]
                rule.prefix = rule_parts[2]

                # create list of possible endings for prediction
                unless rule.suffix.blank?
                    if @endings.has_key?(rule.suffix)
                        @endings[rule.suffix] << rule_id
                    else
                        @endings[rule.suffix] = []
                        @endings[rule.suffix] << rule_id
                    end
                end

                tmp_rules << rule
            end

            @rules[rule_id] = tmp_rules
            @rule_frequencies[rule_id] = 0
            rule_id += 1
        end

        puts '[LEM] ' + @rules.length.to_s + ' rules loaded.'
    end

    def load_accents(file)
        pass_section(file)
    end

    def load_logs(file)
        pass_section(file)
    end

    def load_prefixes(file)
        section_lines = read_section(file)

        section_lines.each do |line|
            @prefixes << line.strip()
        end

        puts '[LEM] ' + @prefixes.length.to_s + ' prefixes loaded.'
    end

    def load_lemmas(file)
        section_lines = read_section(file)

        section_lines.each do |line|
            lemma_parts = line.split()

            # skip accents and user sessions
            lemma = lemma_parts[0]

            annotation = Annotation.new
            annotation.rule = lemma_parts[1].to_i
            annotation.prefix = lemma_parts[3]
            annotation.gram = lemma_parts[4]

            if @lemmas.has_key?(lemma)
                @lemmas[lemma] << annotation
            else
                @lemmas[lemma] = []
                @lemmas[lemma] << annotation
            end

            # count frequencies of rules for future lemma prediction
            @rule_frequencies[annotation.rule] += 1
        end

        puts '[LEM] ' + section_lines.length.to_s + ' lemmas loaded.'
    end

    def read_dictionary(file)
        load_rules(file)
        load_accents(file)
        load_logs(file)
        load_prefixes(file)
        load_lemmas(file)
    end

    def read_gramtab(file)
        while (line = file.gets)
            line = line.strip()
            if line.start_with?('//') || line.blank?
                next
            end

            grams = line.split()
            if grams.length == 3
                grams[3] = ''
            end

            ancode, letter, type, info = grams
            @gramtab[ancode] = [type, info, letter]
        end
    end

    # get normal form of a word
    def normalize(word)
        is_quotes = false

        # word in quotes shouldn't be recognized as location
        if (word.start_with?("\"") and word.end_with?("\"")) or
            (word.start_with?("'") and word.end_with?("'"))
            is_quotes = true
        end

        word = word.gsub(/["']/, '')
        word_str = word

        # try to found word in dictionary
        # on each iteration we cut word by 1 letter
        # i.e. Russia, Russi, Russ...
        until word_str.blank? do
            if @lemmas.has_key?(UnicodeUtils.upcase(word_str))
                annotations = @lemmas.get(UnicodeUtils.upcase(word_str))

                # at first check for location rules
                annotations.each do |annotation|
                    gram_info = @gramtab[annotation.gram]
                    if gram_info.nil? or gram_info[1].nil?
                        is_location = false
                    else
                        is_location = (gram_info[1].include?(LOCATION) and not is_quotes)
                    end

                    if is_location
                        rules = @rules[annotation.rule]

                        rules.each_with_index do |rule, index|
                            if UnicodeUtils.upcase(word_str) + rule.suffix == UnicodeUtils.upcase(word)
                                token = Token.new
                                token.word = word
                                token.normal = UnicodeUtils.upcase(word_str) + rules.first.suffix
                                token.lemma = UnicodeUtils.upcase(word_str)
                                token.rule = annotation.rule
                                token.rule_part = index
                                token.annotation = gram_info
                                token.is_location = is_location

                                return token
                            end
                        end
                    end
                end

                # sort possible rules by id number
                # more general rules have smaller id
                annotations.sort_by{|k|k.rule}.each do |annotation|
                    rules = @rules[annotation.rule]

                    rules.each_with_index do |rule, index|
                        if UnicodeUtils.upcase(word_str) + rule.suffix == UnicodeUtils.upcase(word)
                            gram_info = @gramtab[annotation.gram]

                            token = Token.new
                            token.word = word
                            token.normal = UnicodeUtils.upcase(word_str) + rules.first.suffix
                            token.lemma = UnicodeUtils.upcase(word_str)
                            token.rule = annotation.rule
                            token.rule_part = index
                            token.annotation = gram_info
                            token.is_location = false

                            return token
                        end
                    end
                end
            end

            word_str = word_str[0...word_str.length - 1]
        end

        # try to found word in special lemma '#'
        annotations = @lemmas.get(SPECIAL_LEMMA)
        annotations.each do |annotation|
            rules = @rules[annotation.rule]

            rules.each_with_index do |rule, index|
                if rule.suffix == UnicodeUtils.upcase(word)
                    gram_info = @gramtab[annotation.gram]
                    if gram_info.nil? or gram_info[1].nil?
                        is_location = false
                    else
                        is_location = (gram_info[1].include?(LOCATION) and not is_quotes)
                    end

                    token = Token.new
                    token.word = word
                    token.normal = rules.first.suffix
                    token.lemma = SPECIAL_LEMMA
                    token.rule = annotation.rule
                    token.rule_part = index
                    token.annotation = gram_info
                    token.is_location = is_location

                    return token
                end
            end
        end

        # try to predict a lemma
        5.downto(1).each do |i|
            word_suffix = word[word.length - i..word.length]

            # try to found 5,4,3... suffixes of our word in list of endings
            # if we found it then return predicted normal form of word
            if !word_suffix.nil? and @endings.has_key?(UnicodeUtils.upcase(word_suffix))
                possible_rules = @endings.get(UnicodeUtils.upcase(word_suffix))

                max_frequency = 0
                best_rule = 0
                best_rule_part = 0

                # search for most popular rule
                possible_rules.each do |rule_id|
                    if @rule_frequencies[rule_id] > max_frequency

                        @rules[rule_id].each_with_index do |prule, index|
                            # predict only productive classes (noun, verb, adjective, adverb)
                            if prule.suffix == UnicodeUtils.upcase(word_suffix) and
                                @productive_classes.include?(@gramtab[prule.gram][0])

                                max_frequency = @rule_frequencies[rule_id]
                                best_rule = rule_id
                                best_rule_part = index
                                break
                            end
                        end
                    end
                end

                predicted_word = word[0..-(i + 1)] + @rules[best_rule].first.suffix
                gram_info = @gramtab[@rules[best_rule].first.gram]

                if gram_info.nil? or gram_info[1].nil?
                    is_location = false
                else
                    is_location = (gram_info[1].include?(LOCATION) and not is_quotes)
                end

                if max_frequency > 0
                    token = Token.new
                    token.word = word
                    token.normal = UnicodeUtils.upcase(predicted_word)
                    token.lemma = word[0..-(i + 1)]
                    token.rule = best_rule
                    token.rule_part = best_rule_part
                    token.annotation = gram_info
                    token.is_location = is_location

                    return token
                end
            end
        end

        nil
    end

    def normalize_word(word)
        normalized_word = normalize(word)

        unless normalized_word.nil?
            return normalized_word
        end

        nil
    end

    def normalize_words(words)
        normal_words = []
        words.each do |w|
            normalized_word = normalize(w)

            unless normalized_word.nil?
                normal_words << normalized_word
            end
        end

        normal_words
    end

    # transform word to neccessary form
    def transform_word(lemma, rule_id, annotation)
        if rule_id.nil? or annotation.nil?
            return ''
        end

        @rules[rule_id].each do |r|
            if @kinds[annotation].include?(r.gram)
                return lemma + r.suffix
            end
        end

        ''
    end

    def is_surname?(word)
        if word.nil? or word.annotation.nil? or word.annotation[1].nil?
            return false
        end

        word.annotation[1].include?(SURNAME)
    end

    def is_name?(word)
        rule = @rules[word.rule][word.rule_part]
        @gramtab[rule.gram][1].include?(NAME)
    end

    def is_middle_name?(word)
        rule = @rules[word.rule][word.rule_part]
        @gramtab[rule.gram][1].include?(MIDDLENAME)
    end

    def is_name_part?(word)
        if word.nil?
            false
        else
            is_name?(word) or is_surname?(word) or is_middle_name?(word)
        end

    end

    def get_rule(rule_id)
        @rules[rule_id]
    end

    def get_lemma(lemma)
        @lemmas.get(lemma)
    end

    def get_word_kind(word)
        rule = @rules[word.rule][word.rule_part]
        @kinds.each do |kind, variants|
            if variants.include?(rule.gram)
                return kind
            end
        end

        nil
    end

    def check_coherence(word1, word2)
        if word1.nil? or word2.nil?
            return true
        end

        rule1 = @rules[word1.rule][word1.rule_part]
        info1 = @gramtab[rule1.gram][1]

        if @gramtab[rule1[1]][0] != 'П'
            return true
        end

        rule2 = @rules[word2.rule][word2.rule_part]
        info2 = @gramtab[rule2.gram][1]

        if info1[0...8] == info2[0...8]
            true
        else
            false
        end
    end

    # leave only nouns and adjectives
    # this function is used for getting context of toponym
    def remove_stop_words(words)
        context_words = []
        words.each do |word|
            if word.is_location
                next
            end

            rule = @rules[word.rule][word.rule_part]
            if @context_classes.include?(@gramtab[rule.gram][0])
                context_words << word.normal
            end
        end
        context_words
    end

    def get_word_class(word)
        rule = @rules[word.rule][word.rule_part]
        @gramtab[rule.gram][0]
    end
end