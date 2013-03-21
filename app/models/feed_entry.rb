class FeedEntry < ActiveRecord::Base
    attr_accessible :guid, :name, :published_at, :summary, :url, :location, :tags, :category
    COMMA = ', '

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

    def self.add_feed_with_proxy(feed_url, proxy_host, proxy_port)
        feed = Feedzirra::Feed.fetch_and_parse(feed_url, {:proxy_url => proxy_host, :proxy_port => proxy_port})
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
        FeedEntry.where("published_at < ?", 3.days.ago).destroy_all
    end

    def self.update_feeds_location()
        FeedEntry.all.each do |entry|
            locations = @lemmatizer.define_location(entry.name + '. ' + entry.summary, entry.id)
            self.update_location(entry, locations)
        end
    end

    def self.add_tag(entry, tags)
        if tags.nil? or tags.empty?
            entry.update_attributes({:tags => nil})
            self.update_location(entry, {:name => nil, :coords => nil, :category => nil})
            return true
        end

        tags_str = ''

        tags.each do |tag|
            tag = UnicodeUtils.upcase(tag)

            if tags_str.blank?
                tags_str = tag
            else
                tags_str += COMMA + tag
            end
        end

        unless tags_str.blank?
            locations = @lemmatizer.define_location(tags_str)
            self.update_location(entry, locations)
        end

        return true
    end

    private
    def self.add_entries(entries)
        entries.each do |entry|
            unless exists? :guid => entry.id
                entry_locations = @lemmatizer.define_location(entry.title + '. ' + entry.summary, entry.id)

                item = create!(
                    :name         => entry.title,
                    :summary      => entry.summary,
                    :url          => entry.url,
                    :published_at => entry.published,
                    :guid         => entry.id,
                    :location     => nil,
                    :tags         => nil,
                    :category     => nil
                    )

                self.update_location(item, entry_locations)
            end
        end
        puts "[FEED] #{entries.count} feed entries were added"
    end

    def self.update_location(entry, locations)
        locations_str = ''
        tags = []
        is_global = false
        is_regions = false
        is_predicted = false

        if locations.nil?
            locations = []
        end

        locations.each do |location|
            tags << location[0].name

            # create a list of toponyms coordinates for future displaying on map
            if location[0].category == 'global'
                is_global = true
                unit = Countries.find(location[0].geonameid)
                locations_str += '%.2f,%.2f' % [unit.latitude, unit.longitude] + ';'
            elsif location[0].category == 'predicted'
                is_predicted = true
                if location[0].geonameid.start_with?('g')
                    unit = Geonames.where("geonameid = '#{location[0].geonameid[1..-1]}'").first
                    locations_str += '%.2f,%.2f' % [unit.latitude, unit.longitude] + ';'
                else
                    unit = Countries.find(location[0].geonameid[1..-1])
                    locations_str += '%.2f,%.2f' % [unit.latitude, unit.longitude] + ';'
                end
            else
                if location[0].category != "population"
                    is_regions = true
                end
                unit = Geonames.where("geonameid = '#{location[0].geonameid}'").first
                locations_str += '%.2f,%.2f' % [unit.latitude, unit.longitude] + ';'
            end
        end

        if locations.count > 0
            if is_global
                entry.update_attributes({:category => 'global'})
            elsif is_regions
                entry.update_attributes({:category => 'region'})
            elsif is_predicted
                entry.update_attributes({:category => 'predicted'})
            else
                entry.update_attributes({:category => 'population'})
            end

            locations_str = locations_str[0...-1]
        else
            entry.update_attributes({:category => nil})
        end

        unless locations_str.blank?
            entry.update_attributes({:location => locations_str})
        end

        tags_str = ''
        tags.each do |tag|
            tag = UnicodeUtils.upcase(tag)

            if tags_str.blank?
                tags_str = tag
            else
                tags_str += COMMA + tag
            end
        end
        unless tags_str.blank?
            entry.update_attributes({:tags => tags_str})
        end
    end
end
