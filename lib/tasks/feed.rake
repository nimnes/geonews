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

    desc 'Clear FeedEntry table and Learning corpus'
    task :clearnews => :environment do
        puts '[FEED] DELETING NEWS'.light_green
        time = Benchmark.realtime do
            LearningCorpus.destroy_all
            FeedEntry.destroy_all
        end
        puts "[FEED] DELETING COMPLETED in #{'%.3f' % time} seconds".light_green
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
                arr = line.split(';')
                if arr.present? and Feeds.where('feed_url = ?', arr[0]).empty?
                    FeedEntry.add_feed(arr[0], arr[1].to_i)
                end
            end
        end
        puts "[FEED] READING COMPLETED in #{'%.3f' % time} seconds".light_green
    end


    desc 'Statistics of recognized/not recognized entries'
    task :stat => :environment do
        puts '[FEED] STATISTICS'.light_green
        time = Benchmark.realtime do
            total = FeedEntry.count
            russian = FeedEntry.where("source like '%geonames%'").count
            global = FeedEntry.where("source like '%countries%'").count
            world_cities = FeedEntry.where("source like '%world_cities%'").count
            user_rules = FeedEntry.where("source like '%user_rules%'").count
            learning = FeedEntry.where("source like '%learning%'").count
            not_recognized = FeedEntry.where('source is NULL').count

            puts "Russian          #{russian} [ #{'%.1f' % (russian.to_f / total.to_f * 100)}% ]"
            puts "Global           #{global} [ #{'%.1f' % (global.to_f / total.to_f * 100)}% ]"
            puts "World cities     #{world_cities} [ #{'%.1f' % (world_cities.to_f / total.to_f * 100)}% ]"
            puts "User rules       #{user_rules} [ #{'%.1f' % (user_rules.to_f / total.to_f * 100)}% ]"
            puts "Learning         #{learning} [ #{'%.1f' % (learning.to_f / total.to_f * 100)}% ]"
            puts "Not recognized   #{not_recognized} [ #{'%.1f' % (not_recognized.to_f / total.to_f * 100)}% ]"
            puts "Total            #{total} [ #{'%.1f' % (total.to_f / total.to_f * 100)}% ]".light_cyan
        end
        puts "[FEED] STATISTICS COMPLETED in #{'%.3f' % time} seconds".light_green
    end
end