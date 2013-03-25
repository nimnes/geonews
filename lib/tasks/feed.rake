namespace :feed do
    require 'benchmark'
    require './lib/lemmatizer/lemmatizer.rb'

    desc 'Grab RSS feeds and add new items in database'
    task :update => :environment do
        puts '[FEED] UPDATE'.light_green
        time = Benchmark.realtime do
            lem = Lemmatizer.new
            FeedEntry.set_lemmatizer(lem)
            FeedEntry.update_feeds
        end
        puts "[FEED] UPDATE COMPLETED in #{"%.3f" % time} seconds".light_green
    end

    desc 'Recalculate locations for all news'
    task :reset => :environment do
        puts '[FEED] RESET'.light_green
        time = Benchmark.realtime do
            lem = Lemmatizer.new
            FeedEntry.set_lemmatizer(lem)
            FeedEntry.update_feeds_location
        end
        puts "[FEED] RESET COMPLETED in #{"%.3f" % time} seconds".light_green
    end
end