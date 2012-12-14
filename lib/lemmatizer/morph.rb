# encoding: utf-8
require "unicode_utils/upcase"
require "benchmark" 

class Morph
    @@rules = []
    @@rule_frequencies = []
    @@prefixes = []
    @@lemmas = Containers::Trie.new
    @@endings = Containers::Trie.new
    @@gramtab = {}

    @@PRODUCTIVE_CLASSES = ["NOUN", "С", "Г", 'ИНФИНИТИВ', 'VERB', 'ADJECTIVE', 'П', 'Н']

    def load_dictionary(dict_file, gram_file)
        puts "[INFO] loading dictionary " + dict_file + " with gramtab " + gram_file + "..."

        dictionary_file = File.new(dict_file, "r")
        gramtab_file = File.new(gram_file, "r")

        time = Benchmark.realtime do
            read_dictionary(dictionary_file)
        end
        puts "[INFO] dictionary was loaded in #{"%.3f" % time} seconds"

        time = Benchmark.realtime do
            read_gramtab(gramtab_file)
        end
        puts "[INFO] gramtab file was loaded in #{"%.3f" % time} seconds"

    end

    def read_section(file)
        section_length = file.gets.to_i
        section_lines = []

        for i in 1..section_length
            section_lines[i - 1] = file.gets
        end

        return section_lines
    end

    def pass_section(file)
        read_section(file).each do |line|
        end
    end

    def load_rules(file)
        section_lines = read_section(file)

        rule_id = 0
        section_lines.each do |line| 
            line_rules = line.strip().split('%')

            tmp_rules = []
            line_rules.each do |rule| 
                if rule.blank?
                    next
                end
                
                rule_parts = rule.split('*')

                if rule_parts.length == 2
                    rule_parts[2] = ''
                end

                suffix = rule_parts[0]
                ancode = rule_parts[1]
                prefix = rule_parts[2]

                # create list of possible endings for prediction
                if !suffix.blank?
                    if @@endings.has_key?(suffix)
                        @@endings[suffix] << rule_id
                    else
                        @@endings[suffix] = []
                        @@endings[suffix] << rule_id
                    end
                end

                tmp_rules << rule_parts
            end

            @@rules[rule_id] = tmp_rules
            @@rule_frequencies[rule_id] = 0
            rule_id += 1
        end

        puts "[INFO] " + @@rules.length.to_s + " rules loaded."
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
            @@prefixes << line.strip()
        end

        puts "[INFO] " + @@prefixes.length.to_s + " prefixes loaded."
    end

    def load_lemmas(file)
        section_lines = read_section(file)

        section_lines.each do |line|
            lemma_parts = line.split()

            # skip accents and user sessions
            base = lemma_parts[0]
            rule_id = lemma_parts[1]
            prefix = lemma_parts[3]
            ancode = lemma_parts[4]

            if @@lemmas.has_key?(base)
                @@lemmas[base] << [rule_id, prefix, ancode]
            else
                @@lemmas[base] = []
                @@lemmas[base] << [rule_id, prefix, ancode]
            end

            # count frequencies of rules for future lemma prediction
            @@rule_frequencies[rule_id.to_i] += 1 
        end
        
        puts "[INFO] " + section_lines.length.to_s + " lemmas loaded."
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
            if line.starts_with?('//') || line.blank?
                next
            end

            grams = line.split()
            if grams.length == 3
                grams[3] = ''
            end

            ancode, letter, type, info = grams
            @@gramtab[ancode] = [type, info, letter]
        end
    end

    # get normal form of a word
    def normalize(word)
        word_str = word

        # try to found word in dictionary
        # on each iteration we cut word by 1 letter
        # i.e. Russia, Russi, Russ...
        while !word_str.blank? do
            if @@lemmas.has_key?(UnicodeUtils.upcase(word_str))
                annotations = @@lemmas.get(UnicodeUtils.upcase(word_str))
                annotations.each do |annotation|
                    suffixes = @@rules[annotation[0].to_i]

                    suffixes.each do |suffix|
                        if (UnicodeUtils.upcase(word_str) + suffix[0] == UnicodeUtils.upcase(word))
                            gram_info = @@gramtab[annotation[2]]
                            return [UnicodeUtils.upcase(word_str) + suffixes[0][0], gram_info]                            
                        end
                    end
                end
            end
            word_str = word_str[0...word_str.length - 1]
        end

        # try to found word in special lemma '#'
        annotations = @@lemmas.get('#')
        annotations.each do |annotation|
            suffixes = @@rules[annotation[0].to_i]
        
            suffixes.each do |suffix|
                if (suffix[0] == UnicodeUtils.upcase(word))
                    gram_info = @@gramtab[annotation[2]]
                    return [suffixes[0][0], gram_info]
                end
            end
        end

        # try to predict a lemma
        for i in 5.downto(1) do
            word_suffix = word[word.length - i..word.length]
            # puts word_suffix

            # try to found 5,4,3... suffixes of our word in list of endings
            # if we found it then return predicted normal form of word
            if !word_suffix.nil? and @@endings.has_key?(UnicodeUtils.upcase(word_suffix))
                possible_rules = @@endings.get(UnicodeUtils.upcase(word_suffix))

                max_frequency = 0
                best_rule = 0

                # search for most popular rule 
                possible_rules.each do |rule_id|
                    if @@rule_frequencies[rule_id] > max_frequency 

                        @@rules[rule_id].each do |prule|
                            # predict only productive classes (noun, verb, adjective, adverb)
                            if prule[0] == UnicodeUtils.upcase(word_suffix) and 
                                @@PRODUCTIVE_CLASSES.include?(@@gramtab[prule[1]][0])
                                max_frequency = @@rule_frequencies[rule_id]
                                best_rule = rule_id
                                break
                            end
                        end
                    end
                end

                predicted_word = word[0..-(i + 1)] + @@rules[best_rule][0][0]
                gram_info = @@gramtab[@@rules[best_rule][0][1]]

                if max_frequency > 0
                    return [UnicodeUtils.upcase(predicted_word), gram_info]
                end
            end
        end

        return ["", ""]
    end

    def normalize_words(words)
        normal_words = []
        words.each do |w|
            normal_form = normalize(w)
            h = [w, normal_form[0], normal_form[1]]
            normal_words << h
        end
        return normal_words
    end

    def get_rule(rule_id)
        return @@rules[rule_id]
    end

    def get_lemma(lemma)
        puts @@lemmas.get(lemma)
    end
end