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
        puts "[FEED] UPDATE COMPLETED in #{'%.3f' % time} seconds".light_green
    end

    desc 'Recalculate locations for all news'
    task :reset => :environment do
        puts '[FEED] RESET'.light_green
        time = Benchmark.realtime do
            #LearningCorpus.delete_all

            lem = Lemmatizer.new
            FeedEntry.set_lemmatizer(lem)
            FeedEntry.update_feeds_location
        end
        puts "[FEED] RESET COMPLETED in #{'%.3f' % time} seconds".light_green
    end

    desc 'Read feeds from rssfeeds file and add it to Feeds model'
    task :readfeeds => :environment do
        puts '[FEED] READING FEEDS'.light_green
        time = Benchmark.realtime do
            lem = Lemmatizer.new
            FeedEntry.set_lemmatizer(lem)

            Feeds.delete_all
            feeds_file = File.new('./dicts/rssfeeds')

            while (line = feeds_file.gets)
                if Feeds.where('feed_url = ?', line).empty?
                    FeedEntry.add_feed(line)
                end
            end
        end
        puts "[FEED] READING COMPLETED in #{'%.3f' % time} seconds".light_green
    end
end