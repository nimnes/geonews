class FeedEntry < ActiveRecord::Base
    attr_accessible :guid, :name, :published_at, :summary, :url, :location

    def self.set_lemmatizer(lem)
        @lemmatizer = lem
    end

    def self.add_feed(feed_url)
        feed = Feedzirra::Feed.fetch_and_parse(feed_url)
        add_entries(feed.entries)

        # save feeds in database for future updating
        if Feeds.where("feed_url = ?", feed_url).empty?
            puts "[FEED] add feed #{feed_url} to database"
            Feeds.create!(
                :title          => feed.title,
                :url            => feed.url,
                :feed_url       => feed.feed_url,
                :etag           => feed.etag,
                :last_modified  => feed.last_modified
            )
        end
    end

    def self.update_feeds()
        # update all feeds, new entries will be added in database
        Feeds.all.each do |feed|
            puts "[FEED] updating news from #{feed.feed_url}..."
            feed_to_update = Feedzirra::Parser::RSS.new
            feed_to_update.title = feed.title
            feed_to_update.etag = feed.etag
            feed_to_update.url = feed.url
            feed_to_update.feed_url = feed.feed_url
            feed_to_update.last_modified = feed.last_modified

            updated_feed = Feedzirra::Feed.update(feed_to_update)
            add_entries(updated_feed.new_entries) if updated_feed.updated?

            feed.update_attributes(:last_modified => updated_feed.last_modified)
        end

        # delete old news
        FeedEntry.where("published_at < ?", 1.day.ago).destroy_all
    end

    private
    def self.add_entries(entries)
        entries.each do |entry|
            unless exists? :guid => entry.id
                create!(
                    :name         => entry.title,
                    :summary      => entry.summary,
                    :url          => entry.url,
                    :published_at => entry.published,
                    :guid         => entry.id,
                    :location     => @lemmatizer.define_location(entry.title + ". " + entry.summary)
                    )
            end
        end
        puts "[FEED] #{entries.count} feed entries were added"
    end

    def self.update_location(entry, location)
        entry.update_attributes({:location => location})
    end

    def self.update_from_feed_continuously(feed_url, delay_interval = 15.minutes)
        feed = Feedzirra::Feed.fetch_and_parse(feed_url)
        add_entries(feed.entries)
        loop do
            sleep delay_interval.to_i
            puts "[FEED] updating from feed #{feed_url}"
            feed = Feedzirra::Feed.update(feed)
            add_entries(feed.new_entries) if feed.updated?
        end
    end
end
