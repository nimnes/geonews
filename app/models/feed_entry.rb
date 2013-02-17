class FeedEntry < ActiveRecord::Base
    attr_accessible :guid, :name, :published_at, :summary, :url, :location, :tags, :category

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
        FeedEntry.where("published_at < ?", 1.month.ago).destroy_all
    end

    def self.update_feeds_location()
        FeedEntry.all.each do |entry|
            other_tags = ""

            unless entry.tags.nil?
                # cut old location tag (it's first)
                tags = entry.tags.split(', ', 2)

                if tags.count <= 1
                    other_tags = ""
                else
                    other_tags = tags[1]
                end
            end

            location = @lemmatizer.define_location(entry.name + ". " + entry.summary + ". " + other_tags)

            if location[:name].nil?
                tags = other_tags.split(', ')
                self.add_tag(entry, tags)
            else
                tags = [location[:name]]
                unless other_tags.empty?
                    other_tags = other_tags.split(', ')
                    other_tags.each do |t|
                        tags.append(t)
                    end
                end

                self.add_tag(entry, tags)
            end
        end
    end

    def self.add_tag(entry, tags)
        print entry.guid
        print tags
        if tags.nil? or tags.empty?
            entry.update_attributes({:tags => nil})
            self.update_location(entry, {:name => nil, :coords => nil, :category => nil})
            return true
        end

        tags_str = ""

        tags.each do |tag|
            tag = UnicodeUtils.upcase(tag)

            if tags_str.blank?
                tags_str = tag
            else
                tags_str += ", " + tag
            end
        end

        entry.update_attributes({:tags => tags_str})

        unless tags_str.blank?
            result = @lemmatizer.define_coords(tags_str.split(', '))
            self.update_location(entry, result)
        end

        return true
    end

    private
    def self.add_entries(entries)
        entries.each do |entry|
            unless exists? :guid => entry.id
                entry_location = @lemmatizer.define_location(entry.title + ". " + entry.summary)
                create!(
                    :name         => entry.title,
                    :summary      => entry.summary,
                    :url          => entry.url,
                    :published_at => entry.published,
                    :guid         => entry.id,
                    :location     => entry_location[:coords],
                    :tags         => entry_location[:name],
                    :category     => entry_location[:category]
                    )
            end
        end
        puts "[FEED] #{entries.count} feed entries were added"
    end

    def self.update_location(entry, location)
        entry.update_attributes({:location => location[:coords]})
        entry.update_attributes({:category => location[:category]})
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
