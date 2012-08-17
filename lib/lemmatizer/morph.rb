require "unicode_utils/upcase"

class Morph
	@@rules = []
	@@logs = []
	@@prefixes = []
	@@lemmas = Containers::Trie.new

	def load_dictionary(file_name)
		puts "loading dictionary: " + file_name
		dictionary_file = File.new(file_name, "r")
		read_dictionary(dictionary_file)
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

				tmp_rules << rule_parts
			end

			@@rules[rule_id] = tmp_rules
			rule_id += 1
		end

		puts @@rules.length.to_s + " rules loaded."
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

		puts @@prefixes.length.to_s + " prefixes loaded."
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
		end
		
		puts section_lines.length.to_s + " lemmas loaded."
	end

	def read_dictionary(file)
		load_rules(file)
		load_accents(file)
		load_logs(file)
		load_prefixes(file)
		load_lemmas(file)
		puts "dictionary was successfully loaded."
	end

	# get normal form of a word
	def normalize(word)
		word_str = word
		while !word_str.blank? do
			if @@lemmas.has_key?(UnicodeUtils.upcase(word_str))
				annotations = @@lemmas.get(UnicodeUtils.upcase(word_str))
				annotations.each do |annotation|
					suffixes = @@rules[annotation[0].to_i]

					suffixes.each do |suffix|
						if (UnicodeUtils.upcase(word_str) + suffix[0] == UnicodeUtils.upcase(word))
							puts "Normal form is " + UnicodeUtils.upcase(word_str) + suffixes[0][0]
							return word_str + suffixes[0][0]
						end
					end
				end
				return
			else
				word_str = word_str[0...word_str.length - 1]
			end
		end
	end

	def get_rule(rule_id)
		return @@rules[rule_id]
	end

	def get_lemma(lemma)
		puts @@lemmas.get(lemma)
	end
end