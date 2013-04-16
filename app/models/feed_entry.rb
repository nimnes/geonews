class FeedEntry < ActiveRecord::Base
    attr_accessible :guid, :name, :published_at, :summary, :url, :location, :tags, :category, :source
    COMMA = ', '

    def self.set_lemmatizer(lem)
        @lemmatizer = lem
    end

    def self.add_feed(feed_url)
        feed = Feedzirra::Feed.fetch_and_parse(feed_url)
        add_entries(feed.entries)

        # save feeds in database for future updating
        if Feeds.where('feed_url = ?', feed_url).empty?
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
        if Feeds.where('feed_url = ?', feed_url).empty?
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
        FeedEntry.where('published_at < ?', 1.months.ago).destroy_all
    end

    def self.update_feeds_location()
        completed = 0
        pb = ProgressBar.create(:total => FeedEntry.count, :format => '%e |%b| %p%%'.light_cyan)

        FeedEntry.all.each do |entry|
            locations = @lemmatizer.define_location(entry.name.to_s + '. ' + entry.summary.to_s, entry.guid)
            self.update_location(entry, locations)

            pb.increment
        end
    end

    def self.add_tag(entry, tags)
        if tags.nil? or tags.empty?
            entry.update_attributes({:tags => nil})
            self.update_location(entry, nil)
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

            @lemmatizer.add_to_learning_corpus(entry.name.to_s + '. ' + entry.summary.to_s, locations, [], entry.guid)
        end

        return true
    end

    private
    def self.add_entries(entries)
        entries.each do |entry|
            unless exists? :guid => entry.id
                item = create!(
                    :name         => entry.title,
                    :summary      => entry.summary,
                    :url          => entry.url,
                    :published_at => entry.published,
                    :guid         => entry.id,
                    :location     => nil,
                    :tags         => nil,
                    :category     => nil,
                    :source       => nil
                    )

                entry_locations = @lemmatizer.define_location(entry.title.to_s + '. ' + entry.summary.to_s, entry.id)
                self.update_location(item, entry_locations)
            end
        end
        puts "[FEED] #{entries.count} feed entries were added"
    end

    def self.update_location(entry, locations)
        locations_str = ''
        sources_str = ''
        tags = []
        categories = []

        if locations.nil?
            locations = []
        end

        locations.each do |location, score|
            tags << location.name

            sources_str += location.source + ';'

            # create a list of toponyms coordinates for future displaying on map
            if location.category == COUNTRY
                categories << COUNTRY
                unit = Countries.find(location.geonameid)

                locations_str += COORDS_FMT % [unit.latitude, unit.longitude] + ';'
            elsif location.category == WORLD_POPULATION
                categories << WORLD_POPULATION
                unit = WorldCities.where("geonameid = '#{location.geonameid}'").first

                locations_str += COORDS_FMT % [unit.latitude, unit.longitude] + ';'
            else
                if location.category == POPULATION
                    categories << POPULATION
                else
                    categories << REGIONAL
                end

                unit = Geonames.where("geonameid = '#{location.geonameid}'").first
                locations_str += COORDS_FMT % [unit.latitude, unit.longitude] + ';'
            end
        end

        if locations.present?
            if categories.include?(COUNTRY)
                entry.update_attributes({:category => COUNTRY})
            elsif categories.include?(WORLD_POPULATION)
                entry.update_attributes({:category => WORLD_POPULATION})
            elsif categories.include?(REGIONAL)
                entry.update_attributes({:category => REGIONAL})
            else
                entry.update_attributes({:category => POPULATION})
            end

            locations_str = locations_str[0...-1]
            sources_str = sources_str[0...-1]

            entry.update_attributes({:location => locations_str})
            entry.update_attributes({:source => sources_str})
        else
            entry.update_attributes({:location => nil})
            entry.update_attributes({:category => nil})
            entry.update_attributes({:tags => nil})
            entry.update_attributes({:source => nil})
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

        if tags_str.present?
            entry.update_attributes({:tags => tags_str})
        end
    end
end
