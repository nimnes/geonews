namespace :feed do
    require "benchmark"
    require "./lib/lemmatizer/lemmatizer.rb"

    desc "Grab RSS feeds and add new items in database"
    task :update => :environment do
        puts "[FEED] UPDATE"
        time = Benchmark.realtime do
            lem = Lemmatizer.new
            FeedEntry.set_lemmatizer(lem)
            FeedEntry.update_feeds()
        end
        puts "[FEED] UPDATE COMPLETED in #{"%.3f" % time} seconds"
    end
end