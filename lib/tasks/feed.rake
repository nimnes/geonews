namespace :feed do
    desc "Grab RSS feeds and add new items in database"
    task :update => :environment do
        FeedEntry.update_feeds()
    end
end