require "./lib/lemmatizer/lemmatizer.rb"
$lemmatizer = Lemmatizer.new

unless FeedEntry.any?
    FeedEntry.add_feed("http://www.vesti.ru/vesti.rss")
end