class FeedEntry < ActiveRecord::Base
    attr_accessible :guid, :name, :published_at, :summary, :url, :location

    def self.set_lemmatizer(lemmatizer)
        @lemmatizer = lemmatizer
    end

    def self.update_from_feed(feed_url)
        feed = Feedzirra::Feed.fetch_and_parse(feed_url)
        add_entries(feed.entries)
    end

    private
    def self.add_entries(entries)
        entries.each do |entry|
            puts entry

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
    end

    def self.update_location(entry, location)
        entry.update_attributes({:location => location})
    end

    def self.update_from_feed_continuously(feed_url, delay_interval = 15.minutes)
        feed = Feedzirra::Feed.fetch_and_parse(feed_url)
        add_entries(feed.entries)
        loop do
            sleep delay_interval.to_i
            feed = Feedzirra::Feed.update(feed)
            add_entries(feed.new_entries) if feed.updated?
        end
    end
end
