# encoding: utf-8

class Lemmatizer
	Location = Struct.new(:latitude, :longitude)

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

	def define_location(text)
		sentences = parse_sentences(text)

		sentences.each do |s|
			words = parse_words(s)
		end
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
		sentence = sentence.gsub(/[.?!:;,"'`~-—]/, "")
		words = sentence.split(/\s+/)
	end
end